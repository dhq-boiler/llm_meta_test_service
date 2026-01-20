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
  rescue Exceptions::OllamaUnavailableError => e
    Rails.logger.error "Ollama unavailable: #{e.message}\n#{e.backtrace&.join("\n")}"
    @llm_options = []
    flash.now[:alert] = e.message
  rescue ActiveRecord::RecordNotFound, ActiveRecord::ActiveRecordError => e
    Rails.logger.error "Database error in ChatsController#new: #{e.message}\n#{e.backtrace&.join("\n")}"
    @llm_options = []
    flash.now[:alert] = "Failed to load chat data: #{e.message}"
  rescue HTTParty::Error, Net::HTTPError, Timeout::Error => e
    Rails.logger.error "Network error loading LLM options: #{e.message}\n#{e.backtrace&.join("\n")}"
    @llm_options = []
    flash.now[:alert] = "Failed to connect to LLM server: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "Unexpected error in ChatsController#new: #{e.class} - #{e.message}\n#{e.backtrace&.join("\n")}"
    @llm_options = []
    flash.now[:alert] = "Failed to load LLM: #{e.message}"
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
      rescue Exceptions::OllamaUnavailableError => e
        flash.now[:alert] = e.message
        Rails.logger.error "Ollama unavailable in chat: #{e.message}\n#{e.backtrace&.join("\n")}"
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
        flash.now[:alert] = "Failed to save message: #{e.message}"
        Rails.logger.error "Database error in chat creation: #{e.class} - #{e.message}\n#{e.backtrace&.join("\n")}"
      rescue HTTParty::Error, Net::HTTPError, Timeout::Error => e
        flash.now[:alert] = "Failed to connect to LLM server: #{e.message}"
        Rails.logger.error "Network error in chat: #{e.class} - #{e.message}\n#{e.backtrace&.join("\n")}"
      rescue JSON::ParserError => e
        flash.now[:alert] = "Invalid response from LLM server"
        Rails.logger.error "JSON parse error in chat: #{e.class} - #{e.message}\n#{e.backtrace&.join("\n")}"
      rescue StandardError => e
        flash.now[:alert] = "An error occurred: #{e.message}"
        Rails.logger.error "Unexpected error in chat: #{e.class} - #{e.message}\n#{e.backtrace&.join("\n")}"
      end
    end

    # Reload messages for Turbo Stream
    @messages = @chat.ordered_messages.to_a

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to new_chat_path }
    end
  end

  def clear
    Chat.clear_from_session(session)
    redirect_to new_chat_path, notice: "Chat history has been cleared"
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
