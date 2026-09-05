class CreateSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :sessions, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :user,
        null: false,
        foreign_key: true,
        type: :uuid
    
      table.string :ip_address
      table.string :user_agent
      table.timestamps
    end
  end
end
