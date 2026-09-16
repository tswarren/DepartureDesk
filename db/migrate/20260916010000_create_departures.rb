class CreateDepartures < ActiveRecord::Migration[8.1]
  def up
    widen_reference_sequences
    create_departures
  end

  def down
    drop_table :departures
    execute "DROP FUNCTION IF EXISTS reject_departure_identity_change();"

    remove_check_constraint :reference_sequences, name: "reference_sequences_namespace"
    execute "DELETE FROM reference_sequences WHERE namespace = 'departure'"
    add_check_constraint :reference_sequences,
      "namespace IN ('client', 'supplier')",
      name: "reference_sequences_namespace"
  end

  private

  def widen_reference_sequences
    remove_check_constraint :reference_sequences, name: "reference_sequences_namespace"
    add_check_constraint :reference_sequences,
      "namespace IN ('client', 'supplier', 'departure')",
      name: "reference_sequences_namespace"

    execute <<~SQL
      INSERT INTO reference_sequences (id, agency_id, namespace, next_value, created_at, updated_at)
      SELECT uuidv7(), agencies.id, 'departure', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM agencies
      WHERE NOT EXISTS (
        SELECT 1 FROM reference_sequences
        WHERE reference_sequences.agency_id = agencies.id
          AND reference_sequences.namespace = 'departure'
      );
    SQL
  end

  def create_departures
    create_table :departures, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.string :departure_reference, limit: 8
      table.string :name, null: false, limit: 160
      table.string :description, limit: 2000
      table.date :starts_on
      table.date :ends_on
      table.string :time_zone
      table.string :operating_currency, limit: 3
      table.uuid :responsible_office_id
      table.uuid :responsible_agency_user_id
      table.string :status, null: false, default: "draft"
      table.timestamptz :first_activated_at
      table.timestamptz :departed_at
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :departures, [ :id, :agency_id ], unique: true, name: "index_departures_on_id_and_agency_id"
    add_index :departures, [ :agency_id, :departure_reference ],
      unique: true,
      where: "departure_reference IS NOT NULL",
      name: "index_departures_on_agency_and_reference"
    add_index :departures, [ :agency_id, :status, :starts_on, :id ], name: "index_departures_on_agency_status_starts_on_id"
    add_index :departures, [ :agency_id, :responsible_office_id, :starts_on, :id ],
      name: "index_departures_on_agency_office_starts_on_id"
    add_index :departures, [ :agency_id, :responsible_agency_user_id, :starts_on, :id ],
      name: "index_departures_on_agency_user_starts_on_id"
    add_index :departures, [ :agency_id, :ends_on, :id ], name: "index_departures_on_agency_ends_on_id"

    add_check_constraint :departures,
      "name IS NOT NULL AND btrim(name) <> '' AND char_length(name) <= 160",
      name: "departures_name"
    add_check_constraint :departures,
      "description IS NULL OR (btrim(description) <> '' AND char_length(description) <= 2000)",
      name: "departures_description"
    add_check_constraint :departures,
      "(starts_on IS NULL) = (ends_on IS NULL)",
      name: "departures_dates_paired"
    add_check_constraint :departures,
      "starts_on IS NULL OR starts_on <= ends_on",
      name: "departures_date_order"
    add_check_constraint :departures,
      "operating_currency IS NULL OR operating_currency ~ '^[A-Z]{3}$'",
      name: "departures_operating_currency"
    add_check_constraint :departures,
      "status IN ('draft', 'active', 'departed')",
      name: "departures_status"
    add_check_constraint :departures,
      "lock_version >= 0",
      name: "departures_lock_version"
    add_check_constraint :departures,
      "departure_reference IS NULL OR departure_reference ~ '^D-[0-9]{6}$'",
      name: "departures_reference_format"
    add_check_constraint :departures,
      "(departure_reference IS NULL) = (first_activated_at IS NULL)",
      name: "departures_reference_activation_pair"
    add_check_constraint :departures, <<~SQL.squish, name: "departures_non_draft_has_reference"
      status = 'draft'
      OR (
        departure_reference IS NOT NULL
        AND first_activated_at IS NOT NULL
      )
    SQL
    add_check_constraint :departures,
      "(status = 'departed') = (departed_at IS NOT NULL)",
      name: "departures_departed_at_pair"
    add_check_constraint :departures, <<~SQL.squish, name: "departures_activation_completeness"
      status = 'draft'
      OR (
        name IS NOT NULL AND btrim(name) <> ''
        AND starts_on IS NOT NULL
        AND ends_on IS NOT NULL
        AND time_zone IS NOT NULL AND btrim(time_zone) <> ''
        AND operating_currency IS NOT NULL
        AND responsible_office_id IS NOT NULL
        AND responsible_agency_user_id IS NOT NULL
      )
    SQL

    add_foreign_key :departures, :offices,
      column: [ :responsible_office_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "departures_office_agency_fk"
    add_foreign_key :departures, :agency_users,
      column: [ :responsible_agency_user_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "departures_agency_user_agency_fk"

    execute <<~SQL
      ALTER TABLE departures
        ADD COLUMN name_search_key text
          GENERATED ALWAYS AS (dd_search_normalize(name)) STORED;

      CREATE FUNCTION reject_departure_identity_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id THEN
          RAISE EXCEPTION 'departure identity is immutable';
        END IF;
        IF OLD.departure_reference IS NOT NULL
          AND NEW.departure_reference IS DISTINCT FROM OLD.departure_reference THEN
          RAISE EXCEPTION 'departure identity is immutable';
        END IF;
        IF OLD.first_activated_at IS NOT NULL
          AND NEW.first_activated_at IS DISTINCT FROM OLD.first_activated_at THEN
          RAISE EXCEPTION 'departure identity is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER departures_reject_identity_change
      BEFORE UPDATE ON departures
      FOR EACH ROW EXECUTE FUNCTION reject_departure_identity_change();

      CREATE INDEX index_departures_on_agency_and_name_search_key
        ON departures (agency_id, name_search_key text_pattern_ops);

      CREATE INDEX index_departures_on_agency_starts_on_name_id
        ON departures (agency_id, starts_on, name_search_key, id);
    SQL
  end
end
