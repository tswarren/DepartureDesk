class CreateM3d5ReservationResponseDependencies < ActiveRecord::Migration[8.1]
  def up
    add_reservation_owner_to_identifiers
    add_reservation_fks_to_commitments
    create_response_links
    create_scope_links
    attach_immutability_triggers
  end

  def down
    drop_table :supplier_confirmation_reservation_scope_links
    drop_table :supplier_confirmation_reservation_response_links
    remove_commitment_reservation_fks
    remove_identifier_reservation_owner
  end

  private

  def add_reservation_owner_to_identifiers
    add_column :supplier_issued_identifiers, :supplier_reservation_id, :uuid
    add_index :supplier_issued_identifiers,
      [ :id, :supplier_reservation_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_supplier_identifiers_on_reservation_owner"
    add_index :supplier_issued_identifiers,
      [ :supplier_reservation_id, :supplier_id, :identifier_type, :issuer_context, :normalized_value ],
      unique: true,
      where: "superseded_at IS NULL AND supplier_reservation_id IS NOT NULL",
      name: "index_supplier_identifiers_on_active_reservation_value"
    add_foreign_key :supplier_issued_identifiers, :supplier_reservations,
      column: [ :supplier_reservation_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "supplier_identifiers_reservation_fk"
  end

  def add_reservation_fks_to_commitments
    change_table :supplier_commitments, bulk: true do |table|
      table.uuid :supplier_reservation_id
      table.uuid :supplier_reservation_revision_id
      table.uuid :supplier_reservation_scope_id
      table.uuid :supplier_reservation_event_id
    end
    add_foreign_key :supplier_commitments, :supplier_reservations,
      column: [ :supplier_reservation_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "supplier_commitments_reservation_fk"
    add_foreign_key :supplier_commitments, :supplier_reservation_revisions,
      column: [ :supplier_reservation_revision_id, :supplier_reservation_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_reservation_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "supplier_commitments_reservation_revision_fk"
    add_foreign_key :supplier_commitments, :supplier_reservation_scopes,
      column: [ :supplier_reservation_scope_id, :supplier_reservation_revision_id, :supplier_reservation_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_reservation_revision_id, :supplier_reservation_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "supplier_commitments_reservation_scope_fk"
    add_foreign_key :supplier_commitments, :supplier_reservation_events,
      column: [ :supplier_reservation_event_id, :supplier_reservation_revision_id, :supplier_reservation_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_reservation_revision_id, :supplier_reservation_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "supplier_commitments_reservation_event_fk"
    add_check_constraint :supplier_commitments,
      "(supplier_reservation_id IS NULL AND supplier_reservation_revision_id IS NULL AND supplier_reservation_scope_id IS NULL AND supplier_reservation_event_id IS NULL) OR " \
      "(supplier_reservation_id IS NOT NULL AND supplier_reservation_revision_id IS NOT NULL AND supplier_reservation_event_id IS NOT NULL)",
      name: "supplier_commitments_reservation_shape"
  end

  def create_response_links
    create_table :supplier_confirmation_reservation_response_links, id: :uuid, default: -> { "uuidv7()" } do |table|
      owner_columns(table)
      table.uuid :supplier_confirmation_id, null: false
      table.uuid :supplier_reservation_id, null: false
      table.uuid :supplier_reservation_revision_id, null: false
      table.uuid :supplier_reservation_event_id, null: false
      table.timestamps null: false
    end
    identity_indexes(:supplier_confirmation_reservation_response_links)
    add_index :supplier_confirmation_reservation_response_links,
      [ :supplier_confirmation_id, :supplier_reservation_event_id ],
      unique: true, name: "index_confirmation_response_links_on_pair"
    add_version_fk(:supplier_confirmation_reservation_response_links)
    add_confirmation_fk(:supplier_confirmation_reservation_response_links, "confirmation_response_links")
    add_foreign_key :supplier_confirmation_reservation_response_links, :supplier_reservation_events,
      column: [ :supplier_reservation_event_id, :supplier_reservation_revision_id, :supplier_reservation_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_reservation_revision_id, :supplier_reservation_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "confirmation_response_links_event_fk"
  end

  def create_scope_links
    create_table :supplier_confirmation_reservation_scope_links, id: :uuid, default: -> { "uuidv7()" } do |table|
      owner_columns(table)
      table.uuid :supplier_confirmation_id, null: false
      table.uuid :supplier_reservation_id, null: false
      table.uuid :supplier_reservation_revision_id, null: false
      table.uuid :supplier_reservation_scope_id, null: false
      table.timestamps null: false
    end
    identity_indexes(:supplier_confirmation_reservation_scope_links)
    add_index :supplier_confirmation_reservation_scope_links,
      [ :supplier_confirmation_id, :supplier_reservation_scope_id ],
      unique: true, name: "index_confirmation_scope_links_on_pair"
    add_version_fk(:supplier_confirmation_reservation_scope_links)
    add_confirmation_fk(:supplier_confirmation_reservation_scope_links, "confirmation_scope_links")
    add_foreign_key :supplier_confirmation_reservation_scope_links, :supplier_reservation_scopes,
      column: [ :supplier_reservation_scope_id, :supplier_reservation_revision_id, :supplier_reservation_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_reservation_revision_id, :supplier_reservation_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "confirmation_scope_links_scope_fk"
  end

  def attach_immutability_triggers
    %i[
      supplier_confirmation_reservation_response_links
      supplier_confirmation_reservation_scope_links
    ].each do |table|
      execute <<~SQL
        CREATE TRIGGER #{table}_reject_update BEFORE UPDATE ON #{table}
        FOR EACH ROW EXECUTE FUNCTION reject_m3d_immutable_mutation();
        CREATE TRIGGER #{table}_reject_delete BEFORE DELETE ON #{table}
        FOR EACH ROW EXECUTE FUNCTION reject_m3d_immutable_mutation();
      SQL
    end
  end

  def remove_commitment_reservation_fks
    remove_check_constraint :supplier_commitments, name: "supplier_commitments_reservation_shape"
    remove_foreign_key :supplier_commitments, name: "supplier_commitments_reservation_event_fk"
    remove_foreign_key :supplier_commitments, name: "supplier_commitments_reservation_scope_fk"
    remove_foreign_key :supplier_commitments, name: "supplier_commitments_reservation_revision_fk"
    remove_foreign_key :supplier_commitments, name: "supplier_commitments_reservation_fk"
    remove_column :supplier_commitments, :supplier_reservation_event_id
    remove_column :supplier_commitments, :supplier_reservation_scope_id
    remove_column :supplier_commitments, :supplier_reservation_revision_id
    remove_column :supplier_commitments, :supplier_reservation_id
  end

  def remove_identifier_reservation_owner
    remove_foreign_key :supplier_issued_identifiers, name: "supplier_identifiers_reservation_fk"
    remove_index :supplier_issued_identifiers, name: "index_supplier_identifiers_on_active_reservation_value"
    remove_index :supplier_issued_identifiers, name: "index_supplier_identifiers_on_reservation_owner"
    remove_column :supplier_issued_identifiers, :supplier_reservation_id
  end

  def owner_columns(table)
    table.references :agency, null: false, type: :uuid, foreign_key: true
    table.uuid :departure_id, null: false
    table.uuid :supplier_arrangement_id, null: false
    table.uuid :supplier_arrangement_version_id, null: false
  end

  def identity_indexes(table_name)
    short = table_name.to_s.delete_prefix("supplier_").delete_prefix("confirmation_")
    add_index table_name, [ :id, :agency_id ], unique: true, name: "index_#{short}_on_id_agency"
    add_index table_name,
      [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_#{short}_on_full_owner"
  end

  def add_version_fk(table_name)
    short = table_name.to_s.delete_prefix("supplier_").delete_prefix("confirmation_")
    add_foreign_key table_name, :supplier_arrangement_versions,
      column: [ :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{short}_version_fk"
  end

  def add_confirmation_fk(table_name, prefix)
    add_foreign_key table_name, :supplier_confirmations,
      column: [ :supplier_confirmation_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{prefix}_confirmation_fk"
  end
end
