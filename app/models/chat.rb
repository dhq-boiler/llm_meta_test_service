class Chat < ApplicationRecord
  belongs_to :user, optional: true
  has_many :messages, dependent: :destroy

  validates :llm_uuid, presence: true
  validates :model, presence: true

  # Find existing chat from session or create new one
  class << self
    def find_or_create_for_session(session, current_user, llm_uuid, model)
      chat = find_by_session_chat_id(session, current_user)

      # Create new chat if it doesn't exist or LLM/model has changed
      if chat.nil? || chat.needs_reset?(llm_uuid, model)
        chat = create!(
          user: current_user,
          llm_uuid: llm_uuid,
          model: model
        )
        session[:chat_id] = chat.id
      end

      chat
    end

    def find_by_session_chat_id(session, current_user)
      return nil unless session[:chat_id].present?

      chat = find_by(id: session[:chat_id])
      return nil unless chat

      # For guest users, only get conversations with nil user_id
      # For logged-in users, only get their own conversations
      if current_user
        chat if chat.user_id == current_user.id
      else
        chat if chat.user_id.nil?
      end
    end

    def clear_from_session(session)
      if session[:chat_id].present?
        Chat.where(id: session[:chat_id]).destroy_all
      end
      session.delete(:chat_id)
    end
  end

  # Check if chat needs to be reset due to LLM or model change
  def needs_reset?(new_llm_uuid, new_model)
    llm_uuid != new_llm_uuid || model != new_model
  end

  # Get the LLM type for this chat
  def llm_type(jwt_token)
    llm_options = LlmMetaServerResource.available_llm_options(jwt_token)
    selected_llm = llm_options.find { |opt| opt[:uuid] == llm_uuid }
    selected_llm&.dig(:llm_type) || "unknown"
  end

  # Add a user message to the chat
  def add_user_message(content)
    messages.create!(
      role: "user",
      content: content
    )
  end

  # Add assistant response by sending to LLM
  def add_assistant_response(jwt_token)
    response_content = send_to_llm(jwt_token)

    messages.create!(
      role: "assistant",
      content: response_content,
      llm_type: llm_type(jwt_token)
    )
  end

  # Get all messages in order
  def ordered_messages
    messages.order(:created_at)
  end

  def broadcast(message_html)
    # Build stream name using session ID and @chat.id
    destination = "chat_#{id}"
    Rails.logger.info "Broadcasting to: #{destination}"

    # Broadcast to ChatChannel
    ActionCable.server.broadcast(
      destination,
      {
        action: "new_message",
        html: message_html
      }
    )
  end

  private

  # Send messages to LLM and get response
  def send_to_llm(jwt_token)
    # Get LLM options
    llm_options = LlmMetaServerResource.available_llm_options(jwt_token)

    # Error if no LLM is available
    raise Exceptions::OllamaUnavailableError, "No LLM available" if llm_options.empty?

    # Prepare messages for LLM
    messages_for_llm = ordered_messages.map do |msg|
      { role: msg.role, content: msg.content }
    end

    # Send chat request using LlmMetaServerQuery
    LlmMetaServerQuery.new.call(jwt_token, llm_uuid, model, messages_for_llm)
  end
end
