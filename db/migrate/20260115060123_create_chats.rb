class CreateChats < ActiveRecord::Migration[8.1]
  def change
    create_table :chats do |t|
      t.references :user, null: true, foreign_key: true
      t.string :llm_uuid
      t.string :model

      t.timestamps
    end
  end
end
