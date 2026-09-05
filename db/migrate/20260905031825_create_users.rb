class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.string :email_address, null: false
      table.string :password_digest, null: false
      table.timestamps
    end
    add_index :users, :email_address, unique: true
  end
end
