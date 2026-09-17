class AllowSharedCapacityEventIdempotencyKeys < ActiveRecord::Migration[8.1]
  def up
    remove_index :capacity_events,
      name: "index_capacity_events_on_idempotency_key"

    add_index :capacity_events, :agency_command_idempotency_key_id,
      where: "agency_command_idempotency_key_id IS NOT NULL",
      name: "index_capacity_events_on_idempotency_key"
  end

  def down
    remove_index :capacity_events,
      name: "index_capacity_events_on_idempotency_key"

    add_index :capacity_events, :agency_command_idempotency_key_id,
      unique: true,
      where: "agency_command_idempotency_key_id IS NOT NULL",
      name: "index_capacity_events_on_idempotency_key"
  end
end
