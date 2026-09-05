class AddAgencyProfileAndAuditEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :agencies, :legal_name, :string
    add_column :agencies, :country_code, :string, limit: 2, null: false, default: "US"

    add_check_constraint :agencies,
      "legal_name IS NULL OR btrim(legal_name) <> ''",
      name: "agencies_legal_name_null_or_not_blank"

    add_check_constraint :agencies,
      "country_code ~ '^[A-Z]{2}$'",
      name: "agencies_country_code_format"

    create_table :audit_events,
      id: :uuid,
      default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.string :actor_kind, null: false
      table.references :actor_user, type: :uuid, foreign_key: { to_table: :users }
      table.string :actor_identifier
      table.string :action, null: false
      table.string :subject_type
      table.uuid :subject_id
      table.jsonb :details, null: false, default: {}
      table.datetime :created_at, null: false
    end

    add_check_constraint :audit_events,
      <<~SQL.squish,
        (
          actor_kind = 'user'
          AND actor_user_id IS NOT NULL
          AND actor_identifier IS NULL
        )
        OR
        (
          actor_kind = 'system'
          AND actor_user_id IS NULL
          AND btrim(actor_identifier) <> ''
        )
      SQL
      name: "audit_events_actor_consistency"

    add_check_constraint :audit_events,
      "action ~ '^[a-z][a-z0-9_]*\\.[a-z][a-z0-9_]*$'",
      name: "audit_events_action_format"

    add_check_constraint :audit_events,
      "(subject_type IS NULL) = (subject_id IS NULL)",
      name: "audit_events_subject_consistency"

    add_index :audit_events,
      [ :agency_id, :created_at ],
      name: "index_audit_events_on_agency_id_and_created_at"

    reversible do |direction|
      direction.up { install_append_only_guard }
      direction.down { remove_append_only_guard }
    end
  end

  private

  def install_append_only_guard
    execute <<~SQL
      CREATE FUNCTION prevent_audit_event_mutation() RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        RAISE EXCEPTION 'audit_events are append-only';
      END;
      $$;

      CREATE TRIGGER audit_events_prevent_update
        BEFORE UPDATE ON audit_events
        FOR EACH ROW
        EXECUTE FUNCTION prevent_audit_event_mutation();

      CREATE TRIGGER audit_events_prevent_delete
        BEFORE DELETE ON audit_events
        FOR EACH ROW
        EXECUTE FUNCTION prevent_audit_event_mutation();
    SQL
  end

  def remove_append_only_guard
    execute <<~SQL
      DROP TRIGGER IF EXISTS audit_events_prevent_update ON audit_events;
      DROP TRIGGER IF EXISTS audit_events_prevent_delete ON audit_events;
      DROP FUNCTION IF EXISTS prevent_audit_event_mutation();
    SQL
  end
end
