class Message < ApplicationRecord
  belongs_to :chat
  belongs_to :prompt_manager_prompt_execution,
             class_name: "PromptManager::PromptExecution",
             optional: false

  validates :role, presence: true, inclusion: { in: %w[user assistant] }
end
