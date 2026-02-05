# frozen_string_literal: true

module PromptManager
  class PromptExecution < ApplicationRecord
    has_many :messages, class_name: "Message", foreign_key: "prompt_manager_prompt_execution_id", dependent: :destroy
    belongs_to :previous, class_name: "PromptManager::PromptExecution", optional: true

    before_create :set_execution_id

    private

    def set_execution_id
      self.execution_id ||= SecureRandom.uuid
    end
  end
end