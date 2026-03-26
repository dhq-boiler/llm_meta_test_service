class MigrateLlmUuidToPromptExecutions < ActiveRecord::Migration[8.1]
  def change
    add_column :prompt_navigator_prompt_executions, :llm_uuid, :string unless column_exists?(:prompt_navigator_prompt_executions, :llm_uuid)
    remove_column :chats, :llm_uuid, :string if column_exists?(:chats, :llm_uuid)
    remove_column :chats, :model, :string if column_exists?(:chats, :model)
  end
end
