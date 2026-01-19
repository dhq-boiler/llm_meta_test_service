class ChatsController < ApplicationController
  # Allow access without login
  skip_before_action :authenticate_user!, raise: false

  def new
    # Get or create current conversation
    @chat = current_chat
    @messages = @chat ? @chat.messages.order(:created_at) : []

    # Get LLM options available for guest users
    jwt_token = session[:jwt_token]
    @llm_options = LlmMetaServerResource.available_llm_options(jwt_token)
  rescue Exceptions::OllamaUnavailableError => e
    Rails.logger.error "Ollama unavailable: #{e.message}"
    @llm_options = []
    flash.now[:alert] = e.message
  rescue ActiveRecord::RecordNotFound, ActiveRecord::ActiveRecordError => e
    Rails.logger.error "Database error in ChatsController#new: #{e.message}"
    @llm_options = []
    flash.now[:alert] = "Failed to load chat data: #{e.message}"
  rescue HTTParty::Error, Net::HTTPError, Timeout::Error => e
    Rails.logger.error "Network error loading LLM options: #{e.message}"
    @llm_options = []
    flash.now[:alert] = "Failed to connect to LLM server: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "Unexpected error in ChatsController#new: #{e.class} - #{e.message}"
    @llm_options = []
    flash.now[:alert] = "Failed to load LLM: #{e.message}"
  end

  def create
    @chat = current_chat
    @messages = @chat ? @chat.messages.order(:created_at).to_a : []
    llm_uuid = params[:api_key_uuid]
    model = params[:model]

    # Get LLM options to find the LLM type
    jwt_token = session[:jwt_token]
    llm_options = LlmMetaServerResource.available_llm_options(jwt_token)
    selected_llm = llm_options.find { |opt| opt[:uuid] == llm_uuid }
    llm_type = selected_llm&.dig(:llm_type) || "unknown"

    # Create a new conversation if it doesn't exist or LLM/model has changed
    if @chat.nil? || @chat.llm_uuid != llm_uuid || @chat.model != model
      @chat = Chat.create!(
        user: current_user,
        llm_uuid: llm_uuid,
        model: model
      )
      @messages = []
      session[:chat_id] = @chat.id
    end

    if params[:message].present?
      # Save user message
      user_message = @chat.messages.create!(
        role: "user",
        content: params[:message]
      )
      @messages << user_message

      # Update view by ActionCable
      broadcast_messages_update

      # Send to LLM and get response
      begin
        response = @chat.send_to_llm(jwt_token)

        # Save assistant response with LLM type
        assistant_message = @chat.messages.create!(
          role: "assistant",
          content: response,
          llm_type: llm_type
        )
        @messages << assistant_message

        # Update view by ActionCable
        broadcast_messages_update

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

    # Reload messages to ensure we have the latest state for Turbo Stream
    @messages = @chat.messages.order(:created_at).to_a if @chat

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to new_chat_path }
    end
  end

  def clear
    if session[:chat_id].present?
      chat = Chat.find_by(id: session[:chat_id])
      chat&.destroy
    end
    session.delete(:chat_id)
    redirect_to new_chat_path, notice: "Chat history has been cleared"
  end

  private

  def broadcast_messages_update
    return unless @chat

    # Render messages list HTML
    messages_html = render_to_string(
      partial: "chats/messages_list",
      locals: { messages: @messages },
      formats: [ :html ]
    )

    # Broadcast to ChatChannel
    ChatChannel.broadcast_to(
      @chat,
      {
        action: "new_message",
        html: messages_html
      }
    )
  end

  def current_chat
    return nil unless session[:chat_id].present?

    chat = Chat.find_by(id: session[:chat_id])

    # For guest users, only get conversations with nil user_id,
    # For logged-in users, only get their own conversations
    if current_user
      chat if chat&.user_id == current_user.id
    else
      chat if chat&.user_id.nil?
    end
  end
end
