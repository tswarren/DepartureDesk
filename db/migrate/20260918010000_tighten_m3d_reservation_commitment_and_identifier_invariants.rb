class TightenM3dReservationCommitmentAndIdentifierInvariants < ActiveRecord::Migration[8.1]
  def up
    remove_index :supplier_issued_identifiers, name: "index_supplier_identifiers_on_active_owner_value"
    add_index :supplier_issued_identifiers,
      [ :supplier_arrangement_id, :supplier_id, :identifier_type, :issuer_context, :normalized_value ],
      unique: true,
      where: "superseded_at IS NULL AND supplier_reservation_id IS NULL",
      name: "index_supplier_identifiers_on_active_owner_value"

    remove_check_constraint :supplier_commitments, name: "supplier_commitments_reservation_shape"
    add_check_constraint :supplier_commitments, <<~SQL.squish, name: "supplier_commitments_reservation_shape"
      (
        supplier_reservation_id IS NULL
        AND supplier_reservation_revision_id IS NULL
        AND supplier_reservation_scope_id IS NULL
        AND supplier_reservation_event_id IS NULL
      )
      OR (
        supplier_reservation_id IS NOT NULL
        AND supplier_reservation_revision_id IS NOT NULL
        AND supplier_reservation_scope_id IS NOT NULL
        AND supplier_reservation_event_id IS NOT NULL
      )
    SQL
  end

  def down
    remove_check_constraint :supplier_commitments, name: "supplier_commitments_reservation_shape"
    add_check_constraint :supplier_commitments, <<~SQL.squish, name: "supplier_commitments_reservation_shape"
      (
        supplier_reservation_id IS NULL
        AND supplier_reservation_revision_id IS NULL
        AND supplier_reservation_scope_id IS NULL
        AND supplier_reservation_event_id IS NULL
      )
      OR (
        supplier_reservation_id IS NOT NULL
        AND supplier_reservation_revision_id IS NOT NULL
        AND supplier_reservation_event_id IS NOT NULL
      )
    SQL

    remove_index :supplier_issued_identifiers, name: "index_supplier_identifiers_on_active_owner_value"
    add_index :supplier_issued_identifiers,
      [ :supplier_arrangement_id, :supplier_id, :identifier_type, :issuer_context, :normalized_value ],
      unique: true,
      where: "superseded_at IS NULL",
      name: "index_supplier_identifiers_on_active_owner_value"
  end
end
