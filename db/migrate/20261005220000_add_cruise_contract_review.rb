# frozen_string_literal: true

class AddCruiseContractReview < ActiveRecord::Migration[8.1]
  def change
    change_table :supplier_cost_definitions, bulk: true do |table|
      table.uuid :contract_reviewed_by_id
      table.timestamptz :contract_reviewed_at
      table.string :contract_review_fingerprint, limit: 128
      table.string :contract_review_provenance, limit: 500
      table.boolean :omitted_commission_means_none, null: false, default: false
    end

    add_foreign_key :supplier_cost_definitions, :agency_users,
      column: [ :contract_reviewed_by_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "supplier_cost_definitions_contract_reviewer_fk"

    add_check_constraint :supplier_cost_definitions,
      <<~SQL.squish,
        (
          contract_reviewed_by_id IS NULL
          AND contract_reviewed_at IS NULL
          AND contract_review_fingerprint IS NULL
          AND contract_review_provenance IS NULL
        ) OR (
          stage = 'contracted'
          AND contract_reviewed_by_id IS NOT NULL
          AND contract_reviewed_at IS NOT NULL
          AND contract_review_fingerprint IS NOT NULL
          AND btrim(contract_review_fingerprint) <> ''
          AND char_length(contract_review_fingerprint) <= 128
          AND contract_review_provenance IS NOT NULL
          AND btrim(contract_review_provenance) <> ''
          AND char_length(contract_review_provenance) <= 500
        )
      SQL
      name: "supplier_cost_definitions_contract_review_shape"

    reversible do |direction|
      direction.up { backfill_cruise_contract_reviews }
    end
  end

  private

  def backfill_cruise_contract_reviews
    # Activated Cruise definitions keep the older omission attestation. The
    # exact-version trigger would otherwise reject that one compatibility write.
    execute <<~SQL
      ALTER TABLE supplier_cost_definitions
        DISABLE TRIGGER supplier_cost_definitions_reject_non_draft_mutation
    SQL
    SupplierCostDefinition.reset_column_information
    SupplierCostDefinition
      .where(stage: "contracted", status: "forecast_ready")
      .includes(:supplier_cost_source, :supplier_cost_components, supplier_arrangement_version: :arrangement_item_definitions)
      .find_each do |definition|
        source = definition.supplier_cost_source
        next if source.supplier_resource_id.blank? || definition.forecast_ready_by_id.blank?

        item = definition.supplier_arrangement_version.arrangement_item_definitions.find { |entry|
          entry.arrangement_item_id == source.arrangement_item_id
        }
        next unless item&.category == "cruise"

        definition.update_columns(
          contract_reviewed_by_id: definition.forecast_ready_by_id,
          contract_reviewed_at: definition.forecast_ready_at,
          contract_review_fingerprint: SupplierCostDefinitionFingerprint.call(definition),
          contract_review_provenance: definition.readiness_provenance.presence || "Recorded forecast readiness",
          omitted_commission_means_none: definition.supplier_cost_components.none? { |component|
            component.economic_role == "expected_commission"
          },
          updated_at: Time.current
        )
      end
    execute <<~SQL
      ALTER TABLE supplier_cost_definitions
        ENABLE TRIGGER supplier_cost_definitions_reject_non_draft_mutation
    SQL
  end
end
