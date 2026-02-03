class Message < ApplicationRecord
  belongs_to :chat

  has_one :message_prompt_execution, dependent: :destroy
  has_one :prompt_manager_prompt_execution,
          through: :message_prompt_execution,
          source: :prompt_execution,
          class_name: "PromptManager::PromptExecution"

  validates :role, presence: true, inclusion: { in: %w[user assistant] }
end
