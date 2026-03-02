class CreatePromptNavigatorPromptExecutions < ActiveRecord::Migration[8.1]
  def change
    create_table :prompt_navigator_prompt_executions do |t|
      t.references :previous, foreign_key: { to_table: :prompt_navigator_prompt_executions }, index: true, null: true
      # Unique identifier for prompt execution
      # Used to highlight active entries in History list and display details on click
      t.string :execution_id
      t.text :prompt
      t.string :llm_platform
      t.string :model
      t.string :configuration
      t.text :response

      t.timestamps
    end
  end
end
