class ChatsController < ApplicationController
  # Allow access without login
  skip_before_action :authenticate_user!, raise: false

  def new
    # Find current conversation or create it on create method if not found
    @chat = Chat.find_or_switch_for_session(
      session,
      current_user
    )
    @messages = @chat&.ordered_messages || []

    # Get LLM options available for users
    jwt_token = current_user.id_token if user_signed_in?
    @llm_options = LlmMetaServerResource.available_llm_options(jwt_token)
  rescue StandardError => e
    Rails.logger.error "Error in ChatsController#new: #{e.class} - #{e.message}\n#{e.backtrace&.join("\n")}"
    @llm_options = []
    flash.now[:alert] = "Chat service is currently unavailable. Please try again later."
  end

  def create
    jwt_token = current_user.id_token if user_signed_in?

    # Find or create chat
    # Create chat if not found, now that we have both api_key_uuid and model
    @chat = Chat.find_or_switch_for_session(
      session,
      current_user,
      llm_uuid: params[:api_key_uuid],
      model: params[:model]
    )

    if params[:message].present?
      # Add user message
      @chat.add_user_message(params[:message])

      # Send to LLM and get assistant response
      begin
        @chat.add_assistant_response(jwt_token)
      rescue StandardError => e
        Rails.logger.error "Error in chat response: #{e.class} - #{e.message}\n#{e.backtrace&.join("\n")}"
        # Broadcast error to client
        broadcast_message("An error occurred while getting the response. Please try again.")
      end
    end

    # Return turbo stream to clear form
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to new_chat_path }
    end
  end
end
