# frozen_string_literal: true

class ReplaceHotelSupplierTermsWithAgreementReferences < ActiveRecord::Migration[8.1]
  WORDING_LIMIT = 2_000
  KINDS = %w[
    deposit_derivation attrition deposit_refund
    destination_fee additional_nights early_departure cancellation
  ].freeze
  ITEM_KINDS = %w[deposit_derivation attrition deposit_refund].freeze

  def up
    create_table :supplier_agreement_references, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.uuid :supplier_arrangement_version_id, null: false
      table.uuid :arrangement_item_id
      table.string :kind, null: false
      table.string :governing_wording, null: false, limit: WORDING_LIMIT
      table.string :original_wording, limit: WORDING_LIMIT
      table.string :source_description, null: false, limit: WORDING_LIMIT
      table.string :supplier_reference, limit: WORDING_LIMIT
      table.string :external_reference, limit: WORDING_LIMIT
      table.string :evidence_note, limit: WORDING_LIMIT
      table.uuid :recorded_by_id, null: false
      table.timestamptz :recorded_at, null: false
      table.uuid :copied_from_id
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :supplier_agreement_references, [ :id, :agency_id ],
      unique: true, name: "index_agreement_references_on_id_agency"
    add_index :supplier_agreement_references,
      [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_agreement_references_on_lineage_owner"
    add_index :supplier_agreement_references,
      [ :supplier_arrangement_version_id, :arrangement_item_id, :kind ],
      unique: true, where: "arrangement_item_id IS NOT NULL",
      name: "index_agreement_references_on_version_item_kind"
    add_index :supplier_agreement_references,
      [ :supplier_arrangement_version_id, :kind ],
      unique: true, where: "arrangement_item_id IS NULL",
      name: "index_agreement_references_on_version_kind_without_item"

    add_foreign_key :supplier_agreement_references, :agencies
    add_foreign_key :supplier_agreement_references, :supplier_arrangement_versions,
      column: [ :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "agreement_references_version_fk"
    add_foreign_key :supplier_agreement_references, :arrangement_items,
      column: [ :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "agreement_references_item_fk"
    add_foreign_key :supplier_agreement_references, :supplier_agreement_references,
      column: [ :copied_from_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "agreement_references_copied_from_fk"
    add_foreign_key :supplier_agreement_references, :agency_users,
      column: [ :recorded_by_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "agreement_references_recorder_fk"

    add_check_constraint :supplier_agreement_references, kind_check, name: "agreement_references_kind"
    add_check_constraint :supplier_agreement_references, wording_check, name: "agreement_references_wording"
    add_check_constraint :supplier_agreement_references, provenance_check, name: "agreement_references_provenance"
    add_check_constraint :supplier_agreement_references, "lock_version >= 0", name: "agreement_references_lock_version"

    execute <<~SQL
      CREATE TRIGGER supplier_agreement_references_reject_non_draft
        BEFORE INSERT OR UPDATE OR DELETE ON public.supplier_agreement_references
        FOR EACH ROW EXECUTE FUNCTION reject_non_draft_arrangement_version_definition_mutation();

      CREATE TRIGGER supplier_agreement_references_reject_owner_change
        BEFORE UPDATE ON public.supplier_agreement_references
        FOR EACH ROW EXECUTE FUNCTION reject_supplier_term_owner_change(
          'agency_id', 'departure_id', 'supplier_arrangement_id',
          'supplier_arrangement_version_id', 'arrangement_item_id', 'kind', 'copied_from_id'
        );
    SQL

    drop_table :supplier_deposit_basis_entries, force: :cascade
    drop_table :supplier_deposit_basis_shares, force: :cascade
    drop_table :supplier_deposit_bases, force: :cascade
    drop_table :hotel_attrition_nights, force: :cascade
    drop_table :hotel_attrition_zero_utilization_rates, force: :cascade
    drop_table :hotel_attrition_policies, force: :cascade
    drop_table :supplier_deposit_refund_clarifications, force: :cascade
    execute "DROP FUNCTION public.validate_supplier_deposit_basis_totals()"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def kind_check
    item_kinds = quote_list(ITEM_KINDS)
    optional_kinds = quote_list(KINDS - ITEM_KINDS)
    <<~SQL.squish
      kind IN (#{quote_list(KINDS)}) AND (
        (kind IN (#{item_kinds}) AND arrangement_item_id IS NOT NULL)
        OR kind IN (#{optional_kinds})
      )
    SQL
  end

  def wording_check
    text = ->(column) {
      "#{column} = btrim(#{column}) AND char_length(#{column}) BETWEEN 1 AND #{WORDING_LIMIT}"
    }
    <<~SQL.squish
      #{text.call("governing_wording")} AND (
        (
          kind = 'deposit_refund' AND original_wording IS NOT NULL AND #{text.call("original_wording")}
        ) OR (
          kind <> 'deposit_refund' AND original_wording IS NULL
        )
      )
    SQL
  end

  def provenance_check
    optional = %w[supplier_reference external_reference evidence_note].map { |column|
      "(#{column} IS NULL OR (#{column} = btrim(#{column}) AND char_length(#{column}) BETWEEN 1 AND #{WORDING_LIMIT}))"
    }.join(" AND ")
    <<~SQL.squish
      source_description = btrim(source_description)
      AND char_length(source_description) BETWEEN 1 AND #{WORDING_LIMIT}
      AND #{optional}
    SQL
  end

  def quote_list(values)
    values.map { |value| "'#{value}'" }.join(", ")
  end
end
