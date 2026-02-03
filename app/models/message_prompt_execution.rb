# frozen_string_literal: true

class MessagePromptExecution < ApplicationRecord
  belongs_to :message
  belongs_to :prompt_execution, class_name: "PromptManager::PromptExecution"
end
