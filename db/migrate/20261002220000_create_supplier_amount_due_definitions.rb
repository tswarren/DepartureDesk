# frozen_string_literal: true

class CreateSupplierAmountDueDefinitions < ActiveRecord::Migration[8.1]
  def up
    create_table :supplier_amount_due_definitions, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.uuid :supplier_arrangement_version_id, null: false
      table.string :currency, null: false, limit: 3
      table.string :rule_shape, null: false
      table.jsonb :rule_parameters, null: false, default: {}
      table.string :precision, null: false
      table.string :time_zone, null: false
      table.integer :position, null: false
      table.integer :lock_version, null: false, default: 0
      table.uuid :copied_from_id
      table.timestamps null: false
    end

    add_index :supplier_amount_due_definitions, :supplier_arrangement_version_id,
      unique: true, name: "index_amount_due_definitions_on_version"
    add_index :supplier_amount_due_definitions, [ :id, :agency_id ],
      unique: true, name: "index_amount_due_definitions_on_id_agency"
    add_index :supplier_amount_due_definitions,
      [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_amount_due_definitions_on_lineage_owner"

    add_foreign_key :supplier_amount_due_definitions, :agencies
    add_foreign_key :supplier_amount_due_definitions, :supplier_arrangement_versions,
      column: [ :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "amount_due_definitions_version_fk"
    add_foreign_key :supplier_amount_due_definitions, :supplier_amount_due_definitions,
      column: [ :copied_from_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "amount_due_definitions_copied_from_fk"

    add_check_constraint :supplier_amount_due_definitions,
      "rule_shape = 'fixed_date' AND precision = 'date_only' AND lock_version >= 0 AND char_length(currency) = 3",
      name: "amount_due_definitions_shape"
    add_check_constraint :supplier_amount_due_definitions,
      "jsonb_typeof(rule_parameters) = 'object' AND rule_parameters ? 'date'",
      name: "amount_due_definitions_date"

    create_table :supplier_amount_due_contributors, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.uuid :supplier_arrangement_version_id, null: false
      table.uuid :supplier_amount_due_definition_id, null: false
      table.uuid :supplier_cost_component_id, null: false
      table.integer :position, null: false
      table.integer :lock_version, null: false, default: 0
      table.uuid :copied_from_id
      table.timestamps null: false
    end

    add_index :supplier_amount_due_contributors,
      [ :supplier_amount_due_definition_id, :supplier_cost_component_id ],
      unique: true, name: "index_amount_due_contributors_on_definition_component"
    add_index :supplier_amount_due_contributors, [ :id, :agency_id ],
      unique: true, name: "index_amount_due_contributors_on_id_agency"
    add_index :supplier_amount_due_contributors,
      [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_amount_due_contributors_on_lineage_owner"

    add_foreign_key :supplier_amount_due_contributors, :agencies
    add_foreign_key :supplier_amount_due_contributors, :supplier_amount_due_definitions,
      column: [ :supplier_amount_due_definition_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "amount_due_contributors_definition_fk"
    add_foreign_key :supplier_amount_due_contributors, :supplier_cost_components,
      column: [ :supplier_cost_component_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "amount_due_contributors_component_fk"
    add_foreign_key :supplier_amount_due_contributors, :supplier_arrangement_versions,
      column: [ :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "amount_due_contributors_version_fk"
    add_foreign_key :supplier_amount_due_contributors, :supplier_amount_due_contributors,
      column: [ :copied_from_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "amount_due_contributors_copied_from_fk"
    add_check_constraint :supplier_amount_due_contributors,
      "position > 0 AND lock_version >= 0",
      name: "amount_due_contributors_position"

    execute <<~SQL
      CREATE TRIGGER supplier_amount_due_definitions_reject_non_draft
        BEFORE INSERT OR UPDATE OR DELETE ON public.supplier_amount_due_definitions
        FOR EACH ROW EXECUTE FUNCTION reject_non_draft_arrangement_version_definition_mutation();

      CREATE TRIGGER supplier_amount_due_contributors_reject_non_draft
        BEFORE INSERT OR UPDATE OR DELETE ON public.supplier_amount_due_contributors
        FOR EACH ROW EXECUTE FUNCTION reject_non_draft_arrangement_version_definition_mutation();
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS supplier_amount_due_contributors_reject_non_draft ON public.supplier_amount_due_contributors"
    execute "DROP TRIGGER IF EXISTS supplier_amount_due_definitions_reject_non_draft ON public.supplier_amount_due_definitions"
    drop_table :supplier_amount_due_contributors
    drop_table :supplier_amount_due_definitions
  end
end
