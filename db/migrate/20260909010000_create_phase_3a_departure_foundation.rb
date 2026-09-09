class CreatePhase3aDepartureFoundation < ActiveRecord::Migration[8.1]
  def up
    create_travel_programs
    create_departure_reference_counters
    create_departures
    create_departure_team_assignments
    create_departure_party_role_assignments
  end

  def down
    drop_table :departure_party_role_assignments
    drop_table :departure_team_assignments
    drop_table :departures
    drop_table :departure_reference_counters
    drop_table :travel_programs
  end

  private

  def create_travel_programs
    create_table :travel_programs,
      id: :uuid,
      default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.string :name, null: false
      table.text :description
      table.text :client_facing_description
      table.string :status, null: false, default: "active"
      table.timestamptz :inactivated_at
      table.uuid :inactivated_by_membership_id
      table.string :inactivation_reason
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :travel_programs, [ :id, :agency_id ], unique: true, name: "index_travel_programs_on_id_and_agency_id"
    add_index :travel_programs, [ :id, :agency_id, :status ], unique: true, name: "index_travel_programs_on_id_agency_id_and_status"
    add_index :travel_programs, [ :agency_id, :status, :name ], name: "index_travel_programs_on_agency_id_status_and_name"
    add_index :travel_programs, :name, using: :gin, opclass: :gin_trgm_ops, name: "index_travel_programs_on_name_trgm"

    add_check_constraint :travel_programs, "status IN ('active', 'inactive')", name: "travel_programs_status_valid"
    add_check_constraint :travel_programs, "lock_version >= 0", name: "travel_programs_lock_version_nonnegative"
    add_check_constraint :travel_programs, "btrim(name) <> ''", name: "travel_programs_name_not_blank"
    add_check_constraint :travel_programs,
      <<~SQL.squish,
        (status = 'active'
          AND inactivated_at IS NULL
          AND inactivated_by_membership_id IS NULL
          AND inactivation_reason IS NULL)
        OR
        (status = 'inactive'
          AND inactivated_at IS NOT NULL
          AND inactivated_by_membership_id IS NOT NULL
          AND btrim(inactivation_reason) <> '')
      SQL
      name: "travel_programs_lifecycle_metadata"

    execute <<~SQL
      ALTER TABLE travel_programs
        ADD CONSTRAINT travel_programs_inactivated_by_membership_fk
        FOREIGN KEY (inactivated_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
    SQL
  end

  def create_departure_reference_counters
    create_table :departure_reference_counters,
      id: false do |table|
      table.uuid :agency_id, null: false, primary_key: true
      table.bigint :last_value, null: false, default: 0
      table.timestamps null: false
    end

    add_check_constraint :departure_reference_counters, "last_value >= 0", name: "drc_last_value_nonnegative"

    execute <<~SQL
      ALTER TABLE departure_reference_counters
        ADD CONSTRAINT departure_reference_counters_agency_fk
        FOREIGN KEY (agency_id)
        REFERENCES agencies (id);
    SQL
  end

  def create_departures
    create_table :departures,
      id: :uuid,
      default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :office_id, null: false
      table.string :owning_office_status
      table.uuid :travel_program_id
      table.string :travel_program_status
      table.string :departure_reference, null: false
      table.uuid :creation_idempotency_key, null: false
      table.string :name, null: false
      table.text :description
      table.text :client_facing_description
      table.string :primary_destination
      table.date :start_date, null: false
      table.date :end_date, null: false
      table.date :sales_open_on
      table.date :sales_close_on
      table.string :default_currency, null: false, limit: 3
      table.string :status, null: false, default: "draft"
      table.uuid :created_by_membership_id, null: false
      table.timestamptz :status_changed_at, null: false
      table.uuid :status_changed_by_membership_id, null: false
      table.string :status_reason
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :departures, [ :id, :agency_id ], unique: true, name: "index_departures_on_id_and_agency_id"
    add_index :departures, [ :agency_id, :departure_reference ], unique: true, name: "index_departures_on_agency_id_and_reference"
    add_index :departures, [ :agency_id, :creation_idempotency_key ], unique: true, name: "index_departures_on_agency_id_and_idempotency_key"
    add_index :departures, [ :agency_id, :office_id, :status, :start_date ], name: "index_departures_on_agency_office_status_start"
    add_index :departures, [ :agency_id, :status, :start_date ], name: "index_departures_on_agency_status_start"
    add_index :departures, [ :agency_id, :travel_program_id, :start_date ], name: "index_departures_on_agency_program_start"
    add_index :departures, :name, using: :gin, opclass: :gin_trgm_ops, name: "index_departures_on_name_trgm"
    add_index :departures, :primary_destination, using: :gin, opclass: :gin_trgm_ops, name: "index_departures_on_destination_trgm"
    add_index :departures, :departure_reference, using: :gin, opclass: :gin_trgm_ops, name: "index_departures_on_reference_trgm"

    add_check_constraint :departures, "status IN ('draft', 'planning', 'cancelled')", name: "departures_status_valid"
    add_check_constraint :departures, "lock_version >= 0", name: "departures_lock_version_nonnegative"
    add_check_constraint :departures, "btrim(name) <> ''", name: "departures_name_not_blank"
    add_check_constraint :departures, "end_date >= start_date", name: "departures_date_order"
    add_check_constraint :departures,
      "sales_open_on IS NULL OR sales_close_on IS NULL OR sales_close_on >= sales_open_on",
      name: "departures_sales_date_order"
    add_check_constraint :departures, "default_currency ~ '^[A-Z]{3}$'", name: "departures_currency_format"
    add_check_constraint :departures, "departure_reference ~ '^D-[0-9]{6,}$'", name: "departures_reference_format"
    add_check_constraint :departures,
      <<~SQL.squish,
        (status IN ('draft', 'planning') AND owning_office_status IS NOT NULL AND owning_office_status = 'active')
        OR (status = 'cancelled' AND owning_office_status IS NULL)
      SQL
      name: "departures_owning_office_projection"
    add_check_constraint :departures,
      <<~SQL.squish,
        (travel_program_id IS NULL AND travel_program_status IS NULL)
        OR (travel_program_id IS NOT NULL AND status IN ('draft', 'planning') AND travel_program_status IS NOT NULL AND travel_program_status = 'active')
        OR (travel_program_id IS NOT NULL AND status = 'cancelled' AND travel_program_status IS NULL)
      SQL
      name: "departures_program_projection"
    add_check_constraint :departures,
      <<~SQL.squish,
        (status = 'cancelled' AND btrim(status_reason) <> '')
        OR (status IN ('draft', 'planning') AND status_reason IS NULL)
      SQL
      name: "departures_status_metadata"

    execute <<~SQL
      ALTER TABLE departures
        ADD CONSTRAINT departures_office_same_agency_fk
        FOREIGN KEY (office_id, agency_id)
        REFERENCES offices (id, agency_id);
      ALTER TABLE departures
        ADD CONSTRAINT departures_owning_office_active_projection_fk
        FOREIGN KEY (office_id, agency_id, owning_office_status)
        REFERENCES offices (id, agency_id, status);
      ALTER TABLE departures
        ADD CONSTRAINT departures_program_same_agency_fk
        FOREIGN KEY (travel_program_id, agency_id)
        REFERENCES travel_programs (id, agency_id);
      ALTER TABLE departures
        ADD CONSTRAINT departures_program_active_projection_fk
        FOREIGN KEY (travel_program_id, agency_id, travel_program_status)
        REFERENCES travel_programs (id, agency_id, status);
      ALTER TABLE departures
        ADD CONSTRAINT departures_created_by_membership_fk
        FOREIGN KEY (created_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
      ALTER TABLE departures
        ADD CONSTRAINT departures_status_changed_by_membership_fk
        FOREIGN KEY (status_changed_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
    SQL
  end

  def create_departure_team_assignments
    create_table :departure_team_assignments,
      id: :uuid,
      default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :departure_id, null: false
      table.uuid :agency_membership_id, null: false
      table.string :membership_status
      table.string :assignment_role, null: false
      table.string :member_name_snapshot, null: false
      table.date :effective_from, null: false
      table.date :effective_until
      table.timestamptz :assigned_at, null: false
      table.uuid :assigned_by_membership_id, null: false
      table.timestamptz :ended_at
      table.uuid :ended_by_membership_id
      table.string :ending_reason
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :departure_team_assignments, [ :id, :agency_id ], unique: true, name: "index_dta_on_id_and_agency_id"
    add_index :departure_team_assignments, [ :departure_id, :agency_id ], name: "index_dta_on_departure_and_agency"
    add_index :departure_team_assignments,
      [ :departure_id, :assignment_role ],
      unique: true,
      where: "effective_until IS NULL",
      name: "index_dta_one_current_role"
    add_index :departure_team_assignments, [ :agency_membership_id, :agency_id ], name: "index_dta_on_membership_and_agency"

    add_check_constraint :departure_team_assignments,
      "assignment_role IN ('group_manager', 'responsible_advisor')",
      name: "dta_role_valid"
    add_check_constraint :departure_team_assignments, "lock_version >= 0", name: "dta_lock_version_nonnegative"
    add_check_constraint :departure_team_assignments, "btrim(member_name_snapshot) <> ''", name: "dta_snapshot_not_blank"
    add_check_constraint :departure_team_assignments,
      "effective_until IS NULL OR effective_until >= effective_from",
      name: "dta_range_order"
    add_check_constraint :departure_team_assignments,
      <<~SQL.squish,
        (effective_until IS NULL
          AND ended_at IS NULL
          AND ended_by_membership_id IS NULL
          AND ending_reason IS NULL
          AND membership_status = 'active')
        OR
        (effective_until IS NOT NULL
          AND ended_at IS NOT NULL
          AND ended_by_membership_id IS NOT NULL
          AND btrim(ending_reason) <> ''
          AND membership_status IS NULL)
      SQL
      name: "dta_lifecycle_complete"

    execute <<~SQL
      ALTER TABLE departure_team_assignments
        ADD CONSTRAINT dta_departure_same_agency_fk
        FOREIGN KEY (departure_id, agency_id)
        REFERENCES departures (id, agency_id);
      ALTER TABLE departure_team_assignments
        ADD CONSTRAINT dta_membership_same_agency_fk
        FOREIGN KEY (agency_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
      ALTER TABLE departure_team_assignments
        ADD CONSTRAINT dta_membership_active_projection_fk
        FOREIGN KEY (agency_membership_id, agency_id, membership_status)
        REFERENCES agency_memberships (id, agency_id, status);
      ALTER TABLE departure_team_assignments
        ADD CONSTRAINT dta_assigned_by_membership_fk
        FOREIGN KEY (assigned_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
      ALTER TABLE departure_team_assignments
        ADD CONSTRAINT dta_ended_by_membership_fk
        FOREIGN KEY (ended_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
      ALTER TABLE departure_team_assignments
        ADD CONSTRAINT dta_no_overlapping_intervals
        EXCLUDE USING gist (
          agency_id WITH =,
          departure_id WITH =,
          assignment_role WITH =,
          agency_membership_id WITH =,
          daterange(effective_from, effective_until, '[)') WITH &&
        );
    SQL
  end

  def create_departure_party_role_assignments
    create_table :departure_party_role_assignments,
      id: :uuid,
      default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :departure_id, null: false
      table.uuid :party_id, null: false
      table.string :party_kind, null: false
      table.string :role, null: false
      table.string :party_display_name_snapshot, null: false
      table.boolean :is_primary, null: false, default: false
      table.date :effective_from, null: false
      table.date :effective_until
      table.timestamptz :assigned_at, null: false
      table.uuid :assigned_by_membership_id, null: false
      table.timestamptz :ended_at
      table.uuid :ended_by_membership_id
      table.string :ending_reason
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :departure_party_role_assignments, [ :id, :agency_id ], unique: true, name: "index_dpra_on_id_and_agency_id"
    add_index :departure_party_role_assignments, [ :departure_id, :agency_id ], name: "index_dpra_on_departure_and_agency"
    add_index :departure_party_role_assignments, [ :party_id, :agency_id ], name: "index_dpra_on_party_and_agency"
    add_index :departure_party_role_assignments,
      [ :departure_id, :role ],
      unique: true,
      where: "effective_until IS NULL AND is_primary",
      name: "index_dpra_one_current_primary"

    add_check_constraint :departure_party_role_assignments,
      "role IN ('organizer', 'group_leader', 'sponsor')",
      name: "dpra_role_valid"
    add_check_constraint :departure_party_role_assignments,
      "party_kind IN ('person', 'household', 'organization')",
      name: "dpra_party_kind_valid"
    add_check_constraint :departure_party_role_assignments,
      "role <> 'group_leader' OR party_kind = 'person'",
      name: "dpra_group_leader_person"
    add_check_constraint :departure_party_role_assignments, "lock_version >= 0", name: "dpra_lock_version_nonnegative"
    add_check_constraint :departure_party_role_assignments, "btrim(party_display_name_snapshot) <> ''", name: "dpra_snapshot_not_blank"
    add_check_constraint :departure_party_role_assignments,
      "effective_until IS NULL OR effective_until >= effective_from",
      name: "dpra_range_order"
    add_check_constraint :departure_party_role_assignments,
      <<~SQL.squish,
        (effective_until IS NULL
          AND ended_at IS NULL
          AND ended_by_membership_id IS NULL
          AND ending_reason IS NULL)
        OR
        (effective_until IS NOT NULL
          AND ended_at IS NOT NULL
          AND ended_by_membership_id IS NOT NULL
          AND btrim(ending_reason) <> '')
      SQL
      name: "dpra_lifecycle_complete"

    execute <<~SQL
      ALTER TABLE departure_party_role_assignments
        ADD CONSTRAINT dpra_departure_same_agency_fk
        FOREIGN KEY (departure_id, agency_id)
        REFERENCES departures (id, agency_id);
      ALTER TABLE departure_party_role_assignments
        ADD CONSTRAINT dpra_party_kind_same_agency_fk
        FOREIGN KEY (party_id, agency_id, party_kind)
        REFERENCES parties (id, agency_id, party_kind);
      ALTER TABLE departure_party_role_assignments
        ADD CONSTRAINT dpra_assigned_by_membership_fk
        FOREIGN KEY (assigned_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
      ALTER TABLE departure_party_role_assignments
        ADD CONSTRAINT dpra_ended_by_membership_fk
        FOREIGN KEY (ended_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
      ALTER TABLE departure_party_role_assignments
        ADD CONSTRAINT dpra_no_overlapping_intervals
        EXCLUDE USING gist (
          agency_id WITH =,
          departure_id WITH =,
          role WITH =,
          party_id WITH =,
          daterange(effective_from, effective_until, '[)') WITH &&
        );
    SQL
  end
end
