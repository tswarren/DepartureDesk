class CreatePhase3bCoreCostAndCommitmentTerms < ActiveRecord::Migration[8.1]
  def up
    create_supplier_cost_terms
    create_supplier_cost_term_details
    create_supplier_commitments
    create_supplier_deposit_requirements
    create_supplier_deadlines
  end

  def down
    drop_table :supplier_deadlines
    drop_table :supplier_deposit_requirements
    drop_table :supplier_commitments
    drop_table :supplier_cost_term_manual_estimate_details
    drop_table :supplier_cost_term_minimum_guarantee_details
    drop_table :supplier_cost_term_per_night_details
    drop_table :supplier_cost_term_per_person_details
    drop_table :supplier_cost_term_per_resource_details
    drop_table :supplier_cost_term_fixed_details
    drop_table :supplier_cost_terms
  end

  private

  def create_supplier_cost_terms
    create_table :supplier_cost_terms, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :office_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :arrangement_id, null: false
      table.uuid :reservation_id
      table.uuid :resource_id
      table.uuid :service_occurrence_id
      table.uuid :economic_item_id, null: false, default: -> { "uuidv7()" }
      table.string :economic_item_key, null: false
      table.string :cost_category, null: false
      table.string :quantity_basis, null: false
      table.string :quantity_unit, null: false
      table.string :shape, null: false
      table.string :basis, null: false
      table.string :status, null: false, default: "draft"
      table.string :currency, null: false, limit: 3
      table.date :effective_on
      table.date :effective_until
      table.integer :term_version, null: false, default: 1
      table.string :rounding_method, null: false, default: "nearest_minor_unit"
      table.string :tax_fee_treatment, null: false, default: "excluded"
      table.string :source_reference
      table.text :provenance, null: false
      table.jsonb :evaluation_inputs, null: false, default: {}
      table.uuid :supersedes_term_id
      table.uuid :created_by_membership_id, null: false
      table.timestamptz :status_changed_at, null: false
      table.uuid :status_changed_by_membership_id, null: false
      table.string :status_reason
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :supplier_cost_terms, [ :id, :agency_id ], unique: true, name: "index_sct_on_id_and_agency_id"
    add_index :supplier_cost_terms, [ :id, :agency_id, :office_id, :departure_id ], unique: true, name: "index_sct_on_id_agency_office_departure"
    add_index :supplier_cost_terms, [ :id, :agency_id, :office_id, :departure_id, :arrangement_id ], unique: true, name: "index_sct_on_id_agency_office_departure_arrangement"
    add_index :supplier_cost_terms, [ :arrangement_id, :agency_id ], name: "index_sct_on_arrangement_and_agency"
    add_index :supplier_cost_terms, [ :economic_item_id, :agency_id ], name: "index_sct_on_economic_item_and_agency"
    add_index :supplier_cost_terms, [ :agency_id, :economic_item_key, :basis ],
      unique: true,
      where: "status = 'active'",
      name: "index_sct_one_active_basis_per_item"

    add_check_constraint :supplier_cost_terms, "shape IN ('fixed', 'per_resource', 'per_person', 'per_night', 'minimum_guarantee', 'manual_estimate')", name: "supplier_cost_terms_shape_valid"
    add_check_constraint :supplier_cost_terms, "basis IN ('estimate', 'contracted')", name: "supplier_cost_terms_basis_valid"
    add_check_constraint :supplier_cost_terms, "status IN ('draft', 'active', 'superseded', 'void')", name: "supplier_cost_terms_status_valid"
    add_check_constraint :supplier_cost_terms, "currency ~ '^[A-Z]{3}$'", name: "supplier_cost_terms_currency_format"
    add_check_constraint :supplier_cost_terms, "lock_version >= 0", name: "supplier_cost_terms_lock_version_nonnegative"
    add_check_constraint :supplier_cost_terms, "term_version > 0", name: "supplier_cost_terms_version_positive"
    add_check_constraint :supplier_cost_terms, "btrim(economic_item_key) <> ''", name: "supplier_cost_terms_key_not_blank"
    add_check_constraint :supplier_cost_terms, "btrim(cost_category) <> ''", name: "supplier_cost_terms_category_not_blank"
    add_check_constraint :supplier_cost_terms, "btrim(quantity_basis) <> ''", name: "supplier_cost_terms_quantity_basis_not_blank"
    add_check_constraint :supplier_cost_terms, "btrim(quantity_unit) <> ''", name: "supplier_cost_terms_quantity_unit_not_blank"
    add_check_constraint :supplier_cost_terms, "btrim(provenance) <> ''", name: "supplier_cost_terms_provenance_not_blank"
    add_check_constraint :supplier_cost_terms,
      "effective_until IS NULL OR effective_on IS NULL OR effective_until > effective_on",
      name: "supplier_cost_terms_effective_interval"
    add_check_constraint :supplier_cost_terms,
      <<~SQL.squish,
        (status IN ('draft', 'active') AND status_reason IS NULL)
        OR (status IN ('superseded', 'void') AND btrim(status_reason) <> '')
      SQL
      name: "supplier_cost_terms_status_metadata"

    execute <<~SQL
      ALTER TABLE supplier_cost_terms
        ADD CONSTRAINT supplier_cost_terms_departure_office_fk
        FOREIGN KEY (departure_id, agency_id, office_id)
        REFERENCES departures (id, agency_id, office_id);
      ALTER TABLE supplier_cost_terms
        ADD CONSTRAINT supplier_cost_terms_arrangement_scope_fk
        FOREIGN KEY (arrangement_id, agency_id, office_id, departure_id)
        REFERENCES supplier_arrangements (id, agency_id, office_id, departure_id);
      ALTER TABLE supplier_cost_terms
        ADD CONSTRAINT supplier_cost_terms_reservation_scope_fk
        FOREIGN KEY (reservation_id, agency_id, office_id, departure_id, arrangement_id)
        REFERENCES supplier_reservations (id, agency_id, office_id, departure_id, arrangement_id);
      ALTER TABLE supplier_cost_terms
        ADD CONSTRAINT supplier_cost_terms_resource_scope_fk
        FOREIGN KEY (resource_id, agency_id, office_id, departure_id, arrangement_id)
        REFERENCES supplier_resources (id, agency_id, office_id, departure_id, arrangement_id);
      ALTER TABLE supplier_cost_terms
        ADD CONSTRAINT supplier_cost_terms_occurrence_scope_fk
        FOREIGN KEY (service_occurrence_id, agency_id)
        REFERENCES supplier_service_occurrences (id, agency_id);
      ALTER TABLE supplier_cost_terms
        ADD CONSTRAINT supplier_cost_terms_supersedes_fk
        FOREIGN KEY (supersedes_term_id, agency_id)
        REFERENCES supplier_cost_terms (id, agency_id);
      ALTER TABLE supplier_cost_terms
        ADD CONSTRAINT supplier_cost_terms_created_by_membership_fk
        FOREIGN KEY (created_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
      ALTER TABLE supplier_cost_terms
        ADD CONSTRAINT supplier_cost_terms_status_by_membership_fk
        FOREIGN KEY (status_changed_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
    SQL
  end

  def create_supplier_cost_term_details
    create_amount_detail_table(:supplier_cost_term_fixed_details, :amount_minor_units)
    create_amount_detail_table(:supplier_cost_term_per_resource_details, :unit_amount_minor_units)

    create_table :supplier_cost_term_per_person_details, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :supplier_cost_term_id, null: false
      table.bigint :unit_amount_minor_units, null: false
      table.integer :planning_person_quantity
      table.integer :guaranteed_person_quantity
      table.timestamps null: false
    end
    add_detail_constraints(:supplier_cost_term_per_person_details, :unit_amount_minor_units)
    add_check_constraint :supplier_cost_term_per_person_details,
      "planning_person_quantity IS NOT NULL OR guaranteed_person_quantity IS NOT NULL",
      name: "sct_per_person_quantity_present"
    add_check_constraint :supplier_cost_term_per_person_details,
      "planning_person_quantity IS NULL OR planning_person_quantity > 0",
      name: "sct_per_person_planning_positive"
    add_check_constraint :supplier_cost_term_per_person_details,
      "guaranteed_person_quantity IS NULL OR guaranteed_person_quantity > 0",
      name: "sct_per_person_guaranteed_positive"

    create_amount_detail_table(:supplier_cost_term_per_night_details, :unit_amount_minor_units)

    create_table :supplier_cost_term_minimum_guarantee_details, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :supplier_cost_term_id, null: false
      table.integer :minimum_quantity
      table.bigint :unit_amount_minor_units
      table.bigint :minimum_amount_minor_units
      table.timestamps null: false
    end
    add_detail_indexes_and_fk(:supplier_cost_term_minimum_guarantee_details)
    add_check_constraint :supplier_cost_term_minimum_guarantee_details,
      "minimum_amount_minor_units IS NOT NULL OR (minimum_quantity IS NOT NULL AND unit_amount_minor_units IS NOT NULL)",
      name: "sct_minimum_guarantee_amount_or_quantity"
    add_check_constraint :supplier_cost_term_minimum_guarantee_details,
      "minimum_quantity IS NULL OR minimum_quantity > 0",
      name: "sct_minimum_guarantee_quantity_positive"
    add_check_constraint :supplier_cost_term_minimum_guarantee_details,
      "unit_amount_minor_units IS NULL OR unit_amount_minor_units >= 0",
      name: "sct_minimum_guarantee_unit_nonnegative"
    add_check_constraint :supplier_cost_term_minimum_guarantee_details,
      "minimum_amount_minor_units IS NULL OR minimum_amount_minor_units >= 0",
      name: "sct_minimum_guarantee_amount_nonnegative"

    create_table :supplier_cost_term_manual_estimate_details, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :supplier_cost_term_id, null: false
      table.bigint :forecast_amount_minor_units, null: false
      table.text :reason, null: false
      table.timestamps null: false
    end
    add_detail_constraints(:supplier_cost_term_manual_estimate_details, :forecast_amount_minor_units)
    add_check_constraint :supplier_cost_term_manual_estimate_details, "btrim(reason) <> ''", name: "sct_manual_estimate_reason_not_blank"
  end

  def create_supplier_commitments
    create_table :supplier_commitments, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :office_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :arrangement_id, null: false
      table.uuid :reservation_id
      table.uuid :resource_id
      table.uuid :service_occurrence_id
      table.uuid :governing_term_id, null: false
      table.uuid :supersedes_commitment_id
      table.uuid :economic_item_id, null: false
      table.string :economic_item_key, null: false
      table.string :cost_category, null: false
      table.string :quantity_basis, null: false
      table.string :quantity_unit, null: false
      table.string :currency, null: false, limit: 3
      table.bigint :valuation_amount_minor_units, null: false
      table.jsonb :valuation_details, null: false, default: {}
      table.string :governing_term_snapshot, null: false
      table.string :status, null: false, default: "open"
      table.text :opened_reason, null: false
      table.uuid :created_by_membership_id, null: false
      table.timestamptz :status_changed_at, null: false
      table.uuid :status_changed_by_membership_id, null: false
      table.string :status_reason
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :supplier_commitments, [ :id, :agency_id ], unique: true, name: "index_scom_on_id_and_agency_id"
    add_index :supplier_commitments, [ :arrangement_id, :agency_id ], name: "index_scom_on_arrangement_and_agency"
    add_index :supplier_commitments, [ :governing_term_id, :agency_id ], name: "index_scom_on_governing_term_and_agency"
    add_index :supplier_commitments, [ :agency_id, :economic_item_key ],
      unique: true,
      where: "status = 'open'",
      name: "index_scom_one_open_per_item"

    add_check_constraint :supplier_commitments, "status IN ('open', 'released', 'satisfied', 'superseded', 'cancelled')", name: "supplier_commitments_status_valid"
    add_check_constraint :supplier_commitments, "currency ~ '^[A-Z]{3}$'", name: "supplier_commitments_currency_format"
    add_check_constraint :supplier_commitments, "valuation_amount_minor_units >= 0", name: "supplier_commitments_value_nonnegative"
    add_check_constraint :supplier_commitments, "lock_version >= 0", name: "supplier_commitments_lock_version_nonnegative"
    add_check_constraint :supplier_commitments, "btrim(economic_item_key) <> ''", name: "supplier_commitments_key_not_blank"
    add_check_constraint :supplier_commitments, "btrim(opened_reason) <> ''", name: "supplier_commitments_opened_reason_not_blank"
    add_check_constraint :supplier_commitments,
      "(status = 'open' AND status_reason IS NULL) OR (status <> 'open' AND btrim(status_reason) <> '')",
      name: "supplier_commitments_status_metadata"

    execute <<~SQL
      ALTER TABLE supplier_commitments
        ADD CONSTRAINT supplier_commitments_departure_office_fk
        FOREIGN KEY (departure_id, agency_id, office_id)
        REFERENCES departures (id, agency_id, office_id);
      ALTER TABLE supplier_commitments
        ADD CONSTRAINT supplier_commitments_arrangement_scope_fk
        FOREIGN KEY (arrangement_id, agency_id, office_id, departure_id)
        REFERENCES supplier_arrangements (id, agency_id, office_id, departure_id);
      ALTER TABLE supplier_commitments
        ADD CONSTRAINT supplier_commitments_governing_term_fk
        FOREIGN KEY (governing_term_id, agency_id)
        REFERENCES supplier_cost_terms (id, agency_id);
      ALTER TABLE supplier_commitments
        ADD CONSTRAINT supplier_commitments_supersedes_fk
        FOREIGN KEY (supersedes_commitment_id, agency_id)
        REFERENCES supplier_commitments (id, agency_id);
      ALTER TABLE supplier_commitments
        ADD CONSTRAINT supplier_commitments_created_by_membership_fk
        FOREIGN KEY (created_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
      ALTER TABLE supplier_commitments
        ADD CONSTRAINT supplier_commitments_status_by_membership_fk
        FOREIGN KEY (status_changed_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
    SQL
  end

  def create_supplier_deposit_requirements
    create_table :supplier_deposit_requirements, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :office_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :arrangement_id, null: false
      table.uuid :supplier_cost_term_id
      table.string :name, null: false
      table.bigint :amount_minor_units, null: false
      table.string :currency, null: false, limit: 3
      table.string :due_rule, null: false
      table.date :due_on
      table.boolean :refundable, null: false, default: false
      table.boolean :applies_to_final_balance, null: false, default: true
      table.string :trigger_condition, null: false
      table.text :provenance, null: false
      table.string :status, null: false, default: "active"
      table.uuid :created_by_membership_id, null: false
      table.uuid :status_changed_by_membership_id, null: false
      table.timestamptz :status_changed_at, null: false
      table.string :status_reason
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :supplier_deposit_requirements, [ :id, :agency_id ], unique: true, name: "index_sdr_on_id_and_agency_id"
    add_index :supplier_deposit_requirements, [ :arrangement_id, :agency_id ], name: "index_sdr_on_arrangement_and_agency"
    add_check_constraint :supplier_deposit_requirements, "currency ~ '^[A-Z]{3}$'", name: "supplier_deposits_currency_format"
    add_check_constraint :supplier_deposit_requirements, "amount_minor_units >= 0", name: "supplier_deposits_amount_nonnegative"
    add_check_constraint :supplier_deposit_requirements, "status IN ('active', 'cancelled')", name: "supplier_deposits_status_valid"
    add_check_constraint :supplier_deposit_requirements, "lock_version >= 0", name: "supplier_deposits_lock_version_nonnegative"
    add_check_constraint :supplier_deposit_requirements, "btrim(name) <> ''", name: "supplier_deposits_name_not_blank"
    add_check_constraint :supplier_deposit_requirements, "btrim(due_rule) <> ''", name: "supplier_deposits_due_rule_not_blank"
    add_check_constraint :supplier_deposit_requirements, "btrim(trigger_condition) <> ''", name: "supplier_deposits_trigger_not_blank"
    add_check_constraint :supplier_deposit_requirements, "btrim(provenance) <> ''", name: "supplier_deposits_provenance_not_blank"
    add_check_constraint :supplier_deposit_requirements,
      "(status = 'active' AND status_reason IS NULL) OR (status = 'cancelled' AND btrim(status_reason) <> '')",
      name: "supplier_deposits_status_metadata"

    execute <<~SQL
      ALTER TABLE supplier_deposit_requirements
        ADD CONSTRAINT supplier_deposits_departure_office_fk
        FOREIGN KEY (departure_id, agency_id, office_id)
        REFERENCES departures (id, agency_id, office_id);
      ALTER TABLE supplier_deposit_requirements
        ADD CONSTRAINT supplier_deposits_arrangement_scope_fk
        FOREIGN KEY (arrangement_id, agency_id, office_id, departure_id)
        REFERENCES supplier_arrangements (id, agency_id, office_id, departure_id);
      ALTER TABLE supplier_deposit_requirements
        ADD CONSTRAINT supplier_deposits_cost_term_fk
        FOREIGN KEY (supplier_cost_term_id, agency_id)
        REFERENCES supplier_cost_terms (id, agency_id);
      ALTER TABLE supplier_deposit_requirements
        ADD CONSTRAINT supplier_deposits_created_by_membership_fk
        FOREIGN KEY (created_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
      ALTER TABLE supplier_deposit_requirements
        ADD CONSTRAINT supplier_deposits_status_by_membership_fk
        FOREIGN KEY (status_changed_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
    SQL
  end

  def create_supplier_deadlines
    create_table :supplier_deadlines, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :office_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :arrangement_id, null: false
      # 3B.2 deadlines are deposit-sourced only. Clause-sourced XOR lands with inert clause records in 3B.5.
      table.uuid :source_deposit_requirement_id, null: false
      table.string :name, null: false
      table.date :original_due_on, null: false
      table.date :due_on, null: false
      table.string :status, null: false, default: "open"
      table.uuid :created_by_membership_id, null: false
      table.timestamptz :rescheduled_at
      table.uuid :rescheduled_by_membership_id
      table.string :reschedule_reason
      table.timestamptz :status_changed_at, null: false
      table.uuid :status_changed_by_membership_id, null: false
      table.string :status_reason
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :supplier_deadlines, [ :id, :agency_id ], unique: true, name: "index_sdl_on_id_and_agency_id"
    add_index :supplier_deadlines, [ :source_deposit_requirement_id, :agency_id ], name: "index_sdl_on_deposit_and_agency"
    add_check_constraint :supplier_deadlines, "status IN ('open', 'completed', 'waived', 'cancelled')", name: "supplier_deadlines_status_valid"
    add_check_constraint :supplier_deadlines, "lock_version >= 0", name: "supplier_deadlines_lock_version_nonnegative"
    add_check_constraint :supplier_deadlines, "btrim(name) <> ''", name: "supplier_deadlines_name_not_blank"
    add_check_constraint :supplier_deadlines,
      "(rescheduled_at IS NULL AND rescheduled_by_membership_id IS NULL AND reschedule_reason IS NULL) OR (rescheduled_at IS NOT NULL AND rescheduled_by_membership_id IS NOT NULL AND btrim(reschedule_reason) <> '')",
      name: "supplier_deadlines_reschedule_metadata"
    add_check_constraint :supplier_deadlines,
      "(status = 'open' AND status_reason IS NULL) OR (status <> 'open' AND btrim(status_reason) <> '')",
      name: "supplier_deadlines_status_metadata"

    execute <<~SQL
      ALTER TABLE supplier_deadlines
        ADD CONSTRAINT supplier_deadlines_departure_office_fk
        FOREIGN KEY (departure_id, agency_id, office_id)
        REFERENCES departures (id, agency_id, office_id);
      ALTER TABLE supplier_deadlines
        ADD CONSTRAINT supplier_deadlines_arrangement_scope_fk
        FOREIGN KEY (arrangement_id, agency_id, office_id, departure_id)
        REFERENCES supplier_arrangements (id, agency_id, office_id, departure_id);
      ALTER TABLE supplier_deadlines
        ADD CONSTRAINT supplier_deadlines_deposit_source_fk
        FOREIGN KEY (source_deposit_requirement_id, agency_id)
        REFERENCES supplier_deposit_requirements (id, agency_id);
      ALTER TABLE supplier_deadlines
        ADD CONSTRAINT supplier_deadlines_created_by_membership_fk
        FOREIGN KEY (created_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
      ALTER TABLE supplier_deadlines
        ADD CONSTRAINT supplier_deadlines_rescheduled_by_membership_fk
        FOREIGN KEY (rescheduled_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
      ALTER TABLE supplier_deadlines
        ADD CONSTRAINT supplier_deadlines_status_by_membership_fk
        FOREIGN KEY (status_changed_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
    SQL
  end

  def create_amount_detail_table(table_name, amount_column)
    create_table table_name, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :supplier_cost_term_id, null: false
      table.bigint amount_column, null: false
      table.timestamps null: false
    end
    add_detail_constraints(table_name, amount_column)
  end

  def add_detail_constraints(table_name, amount_column)
    add_detail_indexes_and_fk(table_name)
    add_check_constraint table_name, "#{amount_column} >= 0", name: "#{table_name}_amount_nonnegative"
  end

  def add_detail_indexes_and_fk(table_name)
    short_name = table_name.to_s.sub("supplier_cost_term_", "sct_").sub("_details", "")
    add_index table_name, [ :supplier_cost_term_id, :agency_id ], unique: true, name: "index_#{short_name}_on_term_and_agency"
    execute <<~SQL
      ALTER TABLE #{table_name}
        ADD CONSTRAINT #{short_name}_term_fk
        FOREIGN KEY (supplier_cost_term_id, agency_id)
        REFERENCES supplier_cost_terms (id, agency_id);
    SQL
  end
end
