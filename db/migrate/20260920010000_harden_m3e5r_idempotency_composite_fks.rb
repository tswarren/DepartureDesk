# frozen_string_literal: true

class HardenM3e5rIdempotencyCompositeFks < ActiveRecord::Migration[8.1]
  TABLES = {
    supplier_deposit_external_attestations: "deposit_attestations_idempotency_fk",
    supplier_planning_milestone_occurrences: "planning_milestones_idempotency_fk",
    supplier_exposure_source_qualifications: "exposure_qualifications_idempotency_fk"
  }.freeze

  def up
    TABLES.each do |table, constraint_name|
      preflight_same_agency!(table)
      remove_foreign_key table, name: constraint_name
      add_foreign_key table, :agency_command_idempotency_keys,
        column: [ :agency_command_idempotency_key_id, :agency_id ],
        primary_key: [ :id, :agency_id ],
        name: constraint_name
    end
  end

  def down
    TABLES.each do |table, constraint_name|
      remove_foreign_key table, name: constraint_name
      add_foreign_key table, :agency_command_idempotency_keys,
        column: :agency_command_idempotency_key_id,
        name: constraint_name
    end
  end

  private

  def preflight_same_agency!(table)
    mismatches = execute(<<~SQL.squish).to_a
      SELECT t.id AS row_id, t.agency_id AS row_agency_id, k.agency_id AS key_agency_id
      FROM #{table} t
      INNER JOIN agency_command_idempotency_keys k
        ON k.id = t.agency_command_idempotency_key_id
      WHERE t.agency_command_idempotency_key_id IS NOT NULL
        AND t.agency_id <> k.agency_id
    SQL

    return if mismatches.empty?

    sample = mismatches.first(5).map { |row|
      "row=#{row["row_id"]} row_agency=#{row["row_agency_id"]} key_agency=#{row["key_agency_id"]}"
    }.join("; ")
    raise ActiveRecord::IrreversibleMigration,
      "#{table} has #{mismatches.size} idempotency key(s) from another Agency " \
      "(sample: #{sample}). Resolve before applying same-Agency composite FKs."
  end
end
