class Chat < ApplicationRecord
  belongs_to :user, optional: true
  has_many :messages, dependent: :destroy

  validates :llm_uuid, presence: true
  validates :model, presence: true

  # Send messages to LLM and get response
  def send_to_llm(jwt_token)
    # Get LLM options
    llm_options = LlmMetaServerResource.available_llm_options(jwt_token)

    # Error if no LLM is available
    raise Exceptions::OllamaUnavailableError, "No LLM available" if llm_options.empty?


    # Prepare messages for LLM
    messages_for_llm = messages.order(:created_at).map do |msg|
      { role: msg.role, content: msg.content }
    end

    # Send chat request using LlmMetaServerQuery
    LlmMetaServerQuery.new.call(jwt_token, llm_uuid, model, messages_for_llm)
  end
end
