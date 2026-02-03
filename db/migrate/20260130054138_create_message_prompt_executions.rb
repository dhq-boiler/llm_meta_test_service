class CreateMessagePromptExecutions < ActiveRecord::Migration[8.1]
  def change
    create_table :message_prompt_executions do |t|
      t.references :message, null: false, foreign_key: true
      t.references :prompt_execution, null: false, foreign_key: { to_table: :prompt_manager_prompt_executions }

      t.timestamps
    end

    add_index :message_prompt_executions, [ :message_id, :prompt_execution_id ], unique: true, name: 'index_message_prompt_executions_uniqueness'
  end
end
