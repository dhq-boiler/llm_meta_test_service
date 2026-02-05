class Chat < ApplicationRecord
  belongs_to :user, optional: true
  has_many :messages, dependent: :destroy

  before_create :set_uuid

  validates :llm_uuid, presence: true
  validates :model, presence: true

  # Find existing chat from session or create new one
  class << self
    def find_or_switch_for_session(session, current_user, llm_uuid: llm_uuid, model: model)
      chat = find_by_session_chat_id(session, current_user)
      return chat if llm_uuid.nil? || model.nil?

      # Create new chat if it doesn't exist or LLM/model has changed
      if llm_uuid.present? && model.present? && (chat.nil? || (chat.present? && chat.needs_reset?(llm_uuid, model)))
        chat = create!(
          user: current_user,
          llm_uuid: llm_uuid,
          model: model
        )
        session[:chat_id] = chat.id
      end

      chat
    end

    private

    def find_by_session_chat_id(session, current_user)
      return nil unless session[:chat_id].present?

      chat = includes(:messages).find_by(id: session[:chat_id])
      return nil unless chat

      # For guest users, only get conversations with nil user_id
      # For logged-in users, only get their own conversations
      if current_user
        chat if chat.user_id == current_user.id
      else
        chat if chat.user_id.nil?
      end
    end
  end

  # Get the LLM type for this chat
  def llm_type(jwt_token)
    llm_options = LlmMetaServerResource.available_llm_options(jwt_token)
    selected_llm = llm_options.find { |opt| opt[:uuid] == llm_uuid }
    selected_llm&.dig(:llm_type) || "unknown"
  end

  # Add a user message to the chat
  def add_user_message(message, model, branch_from_uuid = nil)
    parent_message = branch_from_uuid.present? ? messages.find_by(uuid: branch_from_uuid) : nil
    prompt_execution = PromptManager::PromptExecution.create!(
      prompt: message,
      model: model,
      configuration: "",
      previous_id: parent_message&.prompt_manager_prompt_execution_id
    )

    new_message = messages.create!(
      role: "user",
      prompt_manager_prompt_execution: prompt_execution
    )

    [ prompt_execution, new_message ]
  end

  # Add assistant response by sending to LLM
  def add_assistant_response(prompt_execution, jwt_token)
    response_content = send_to_llm(jwt_token)
    prompt_execution.update!(
      llm_platform: llm_type(jwt_token),
      response: response_content
    )
    new_message = messages.create!(
      role: "assistant",
      prompt_manager_prompt_execution: prompt_execution
    )

    new_message
  end

  # Get all messages in order
  def ordered_messages
    messages
      .includes(:prompt_manager_prompt_execution)
      .order(:created_at)
  end

  def ordered_by_descending_prompt_executions
    messages
      .where(role: "user")
      .includes(:prompt_manager_prompt_execution)
      .order(created_at: :desc)
      .to_a
      .select { |msg| msg.prompt_manager_prompt_execution }
      .map(&:prompt_manager_prompt_execution)
  end

  # Check if chat needs to be reset due to LLM or model change
  def needs_reset?(new_llm_uuid, new_model)
    llm_uuid != new_llm_uuid || model != new_model
  end

  private

  # Set a new UUID
  def set_uuid
    self.uuid = SecureRandom.uuid
  end

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
