class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :google_id
      t.text :id_token

      t.timestamps null: false
    end

    add_index :users, :email, unique: true
    add_index :users, :google_id, unique: true
  end
end
