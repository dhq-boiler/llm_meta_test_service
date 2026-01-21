class ChatsController < ApplicationController
  # Allow access without login
  skip_before_action :authenticate_user!, raise: false

  def new
    # Get or create current conversation
    @chat = Chat.find_from_session(session, current_user)
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
    @chat = Chat.find_or_create_for_session(
      session,
      current_user,
      params[:api_key_uuid],
      params[:model]
    )

    if params[:message].present?
      # Add user message
      user_message = @chat.add_user_message(params[:message])
      broadcast_message(user_message)

      # Send to LLM and get assistant response
      begin
        assistant_message = @chat.add_assistant_response(jwt_token)
        broadcast_message(assistant_message)
      rescue StandardError => e
        Rails.logger.error "Error in chat response: #{e.class} - #{e.message}\n#{e.backtrace&.join("\n")}"
        flash.now[:alert] = "An error occurred while sending your message. Please try again."
      end
    end

    # Reload messages for Turbo Stream
    @messages = @chat.ordered_messages.to_a

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to new_chat_path }
    end
  end

  private

  def broadcast_message(message)
    return unless @chat

    # Render single message HTML
    message_html = render_to_string(
      partial: "chats/message",
      locals: { message: message },
      formats: [ :html ]
    )

    # Broadcast to ChatChannel
    ChatChannel.broadcast_to(
      @chat,
      {
        action: "new_message",
        html: message_html
      }
    )
  end
end
