# frozen_string_literal: true

# Slice 1 step 1 (REF-02, REF-05, D-84, D-89): Departure references become
# DEP- and at least four digits, and the sequence table gains the reference
# types later steps issue. Only the six-digit client and supplier formats keep
# the 1,000,000 limit. No retained Departure has a D- reference (D-84).
class AddReferenceNamespaces < ActiveRecord::Migration[8.1]
  NAMESPACES = %w[client supplier departure trip client_payment arrangement supplier_payment confirmation invoice receipt].freeze
  NEW_NAMESPACES = %w[trip client_payment arrangement supplier_payment confirmation invoice receipt].freeze

  def up
    issued = select_value("SELECT count(*) FROM departures WHERE departure_reference IS NOT NULL").to_i
    if issued.positive?
      raise "#{issued} Departures hold a D- reference. D-84 assumes none are retained; recreate this database."
    end

    remove_check_constraint :departures, name: "departures_reference_format"
    change_column :departures, :departure_reference, :string, limit: nil
    add_check_constraint :departures,
      "departure_reference IS NULL OR departure_reference ~ '^DEP-[0-9]{4,}$'",
      name: "departures_reference_format"

    remove_check_constraint :reference_sequences, name: "reference_sequences_namespace"
    add_check_constraint :reference_sequences,
      "namespace IN (#{NAMESPACES.map { |namespace| quote(namespace) }.join(", ")})",
      name: "reference_sequences_namespace"
    remove_check_constraint :reference_sequences, name: "reference_sequences_next_value"
    add_check_constraint :reference_sequences,
      "next_value >= 1 AND (namespace NOT IN ('client', 'supplier') OR next_value <= 1000000)",
      name: "reference_sequences_next_value"

    NEW_NAMESPACES.each do |namespace|
      execute <<~SQL
        INSERT INTO reference_sequences (agency_id, namespace, next_value, created_at, updated_at)
        SELECT agencies.id, #{quote(namespace)}, 1, now(), now() FROM agencies
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
