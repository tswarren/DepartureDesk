class AddSupplierClausesAndClauseDeadlines < ActiveRecord::Migration[8.1]
  def up
    create_supplier_clauses
    extend_supplier_deadline_sources
  end

  def down
    restore_deposit_only_deadline_sources
    drop_table :supplier_clauses
  end

  private

  def create_supplier_clauses
    create_table :supplier_clauses, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :office_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :arrangement_id, null: false
      table.uuid :resource_id
      table.uuid :service_occurrence_id
      table.uuid :governing_term_id
      table.uuid :affected_commitment_id
      table.string :clause_type, null: false
      table.string :name, null: false
      table.string :capacity_action, null: false, default: "none"
      table.integer :capacity_quantity
      table.integer :guaranteed_quantity
      table.string :commitment_action, null: false, default: "none"
      table.bigint :amount_minor_units
      table.string :currency, limit: 3
      table.date :effective_on
      table.date :effective_until
      table.date :trigger_on
      table.date :deadline_due_on
      table.text :provenance, null: false
      table.jsonb :application_rules, null: false, default: {}
      table.uuid :created_by_membership_id, null: false
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :supplier_clauses, [ :id, :agency_id ], unique: true, name: "index_scl_on_id_and_agency_id"
    add_index :supplier_clauses, [ :arrangement_id, :agency_id ], name: "index_scl_on_arrangement_and_agency"
    add_index :supplier_clauses, [ :resource_id, :service_occurrence_id ], name: "index_scl_on_resource_occurrence"
    add_index :supplier_clauses, [ :governing_term_id, :agency_id ], name: "index_scl_on_governing_term_and_agency"
    add_index :supplier_clauses, [ :affected_commitment_id, :agency_id ], name: "index_scl_on_commitment_and_agency"

    add_check_constraint :supplier_clauses, "clause_type IN ('release', 'attrition', 'cancellation', 'guarantee')", name: "supplier_clauses_type_valid"
    add_check_constraint :supplier_clauses, "capacity_action IN ('none', 'release', 'reduction', 'expiration', 'guarantee_adjustment')", name: "supplier_clauses_capacity_action_valid"
    add_check_constraint :supplier_clauses, "commitment_action IN ('none', 'open', 'release', 'satisfy', 'cancel')", name: "supplier_clauses_commitment_action_valid"
    add_check_constraint :supplier_clauses, "capacity_quantity IS NULL OR capacity_quantity > 0", name: "supplier_clauses_capacity_quantity_positive"
    add_check_constraint :supplier_clauses, "guaranteed_quantity IS NULL OR guaranteed_quantity >= 0", name: "supplier_clauses_guaranteed_quantity_nonnegative"
    add_check_constraint :supplier_clauses, "amount_minor_units IS NULL OR amount_minor_units >= 0", name: "supplier_clauses_amount_nonnegative"
    add_check_constraint :supplier_clauses, "currency IS NULL OR currency ~ '^[A-Z]{3}$'", name: "supplier_clauses_currency_format"
    add_check_constraint :supplier_clauses, "lock_version >= 0", name: "supplier_clauses_lock_version_nonnegative"
    add_check_constraint :supplier_clauses, "btrim(name) <> ''", name: "supplier_clauses_name_not_blank"
    add_check_constraint :supplier_clauses, "btrim(provenance) <> ''", name: "supplier_clauses_provenance_not_blank"
    add_check_constraint :supplier_clauses,
      "effective_until IS NULL OR effective_on IS NULL OR effective_until > effective_on",
      name: "supplier_clauses_effective_interval"
    add_check_constraint :supplier_clauses,
      "capacity_action = 'none' OR (resource_id IS NOT NULL AND service_occurrence_id IS NOT NULL AND (capacity_quantity IS NOT NULL OR (capacity_action = 'guarantee_adjustment' AND guaranteed_quantity IS NOT NULL)))",
      name: "supplier_clauses_capacity_target_complete"
    add_check_constraint :supplier_clauses,
      "commitment_action <> 'open' OR governing_term_id IS NOT NULL",
      name: "supplier_clauses_open_commitment_term_required"
    add_check_constraint :supplier_clauses,
      "commitment_action NOT IN ('release', 'satisfy', 'cancel') OR affected_commitment_id IS NOT NULL",
      name: "supplier_clauses_existing_commitment_required"
    add_check_constraint :supplier_clauses,
      "clause_type <> 'guarantee' OR (guaranteed_quantity IS NOT NULL OR amount_minor_units IS NOT NULL OR governing_term_id IS NOT NULL)",
      name: "supplier_clauses_guarantee_substance"

    execute <<~SQL
      ALTER TABLE supplier_clauses
        ADD CONSTRAINT supplier_clauses_departure_office_fk
        FOREIGN KEY (departure_id, agency_id, office_id)
        REFERENCES departures (id, agency_id, office_id);
      ALTER TABLE supplier_clauses
        ADD CONSTRAINT supplier_clauses_arrangement_scope_fk
        FOREIGN KEY (arrangement_id, agency_id, office_id, departure_id)
        REFERENCES supplier_arrangements (id, agency_id, office_id, departure_id);
      ALTER TABLE supplier_clauses
        ADD CONSTRAINT supplier_clauses_resource_scope_fk
        FOREIGN KEY (resource_id, agency_id, office_id, departure_id, arrangement_id)
        REFERENCES supplier_resources (id, agency_id, office_id, departure_id, arrangement_id);
      ALTER TABLE supplier_clauses
        ADD CONSTRAINT supplier_clauses_occurrence_scope_fk
        FOREIGN KEY (service_occurrence_id, agency_id)
        REFERENCES supplier_service_occurrences (id, agency_id);
      ALTER TABLE supplier_clauses
        ADD CONSTRAINT supplier_clauses_governing_term_fk
        FOREIGN KEY (governing_term_id, agency_id)
        REFERENCES supplier_cost_terms (id, agency_id);
      ALTER TABLE supplier_clauses
        ADD CONSTRAINT supplier_clauses_affected_commitment_fk
        FOREIGN KEY (affected_commitment_id, agency_id)
        REFERENCES supplier_commitments (id, agency_id);
      ALTER TABLE supplier_clauses
        ADD CONSTRAINT supplier_clauses_created_by_membership_fk
        FOREIGN KEY (created_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
    SQL
  end

  def extend_supplier_deadline_sources
    change_column_null :supplier_deadlines, :source_deposit_requirement_id, true
    add_column :supplier_deadlines, :source_clause_id, :uuid
    add_index :supplier_deadlines, [ :source_clause_id, :agency_id ], name: "index_sdl_on_clause_and_agency"
    add_check_constraint :supplier_deadlines,
      "(source_deposit_requirement_id IS NOT NULL)::integer + (source_clause_id IS NOT NULL)::integer = 1",
      name: "supplier_deadlines_exactly_one_source"

    execute <<~SQL
      ALTER TABLE supplier_deadlines
        ADD CONSTRAINT supplier_deadlines_clause_source_fk
        FOREIGN KEY (source_clause_id, agency_id)
        REFERENCES supplier_clauses (id, agency_id);
    SQL
  end

  def restore_deposit_only_deadline_sources
    remove_foreign_key :supplier_deadlines, name: "supplier_deadlines_clause_source_fk"
    remove_check_constraint :supplier_deadlines, name: "supplier_deadlines_exactly_one_source"
    remove_index :supplier_deadlines, name: "index_sdl_on_clause_and_agency"
    remove_column :supplier_deadlines, :source_clause_id
    change_column_null :supplier_deadlines, :source_deposit_requirement_id, false
  end
end
