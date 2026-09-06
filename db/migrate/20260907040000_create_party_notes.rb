class CreatePartyNotes < ActiveRecord::Migration[8.1]
  def up
    create_table :party_notes,
      id: :uuid,
      default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :party_id, null: false
      table.uuid :author_membership_id, null: false
      table.text :body, null: false
      table.string :visibility, null: false
      table.boolean :pinned, null: false, default: false
      table.string :record_status, null: false, default: "active"
      table.uuid :superseded_by_note_id
      table.timestamptz :corrected_at
      table.uuid :corrected_by_membership_id
      table.string :correction_reason
      table.timestamptz :removed_at
      table.uuid :removed_by_membership_id
      table.string :removal_reason
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :party_notes, [ :id, :agency_id ], unique: true, name: "index_party_notes_on_id_and_agency_id"
    add_index :party_notes, [ :party_id, :agency_id ], name: "index_party_notes_on_party_id_and_agency_id"
    add_index :party_notes, [ :party_id, :pinned, :created_at ], name: "index_party_notes_on_party_pinned_and_created_at"

    add_check_constraint :party_notes,
      "visibility IN ('standard', 'administrator_only')",
      name: "party_notes_visibility_valid"
    add_check_constraint :party_notes,
      "record_status IN ('active', 'superseded', 'removed')",
      name: "party_notes_record_status_valid"
    add_check_constraint :party_notes,
      "btrim(body) <> ''",
      name: "party_notes_body_not_blank"
    add_check_constraint :party_notes,
      "lock_version >= 0",
      name: "party_notes_lock_version_nonnegative"
    add_check_constraint :party_notes,
      "superseded_by_note_id IS NULL OR superseded_by_note_id <> id",
      name: "party_notes_no_self_supersession"
    add_check_constraint :party_notes,
      <<~SQL.squish,
        (record_status = 'active'
          AND superseded_by_note_id IS NULL
          AND corrected_at IS NULL
          AND corrected_by_membership_id IS NULL
          AND correction_reason IS NULL
          AND removed_at IS NULL
          AND removed_by_membership_id IS NULL
          AND removal_reason IS NULL)
        OR
        (record_status = 'superseded'
          AND superseded_by_note_id IS NOT NULL
          AND corrected_at IS NOT NULL
          AND corrected_by_membership_id IS NOT NULL
          AND btrim(correction_reason) <> ''
          AND removed_at IS NULL
          AND removed_by_membership_id IS NULL
          AND removal_reason IS NULL)
        OR
        (record_status = 'removed'
          AND removed_at IS NOT NULL
          AND removed_by_membership_id IS NOT NULL
          AND btrim(removal_reason) <> '')
      SQL
      name: "party_notes_disposition_matches_status"

    execute <<~SQL
      ALTER TABLE party_notes
        ADD CONSTRAINT party_notes_party_same_agency_fk
        FOREIGN KEY (party_id, agency_id)
        REFERENCES parties (id, agency_id);
      ALTER TABLE party_notes
        ADD CONSTRAINT party_notes_author_membership_fk
        FOREIGN KEY (author_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
      ALTER TABLE party_notes
        ADD CONSTRAINT party_notes_corrected_by_membership_fk
        FOREIGN KEY (corrected_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
      ALTER TABLE party_notes
        ADD CONSTRAINT party_notes_removed_by_membership_fk
        FOREIGN KEY (removed_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
      ALTER TABLE party_notes
        ADD CONSTRAINT party_notes_superseded_by_fk
        FOREIGN KEY (superseded_by_note_id, agency_id)
        REFERENCES party_notes (id, agency_id);
    SQL

    execute <<~SQL
      CREATE FUNCTION party_notes_prevent_body_or_identity_change() RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF NEW.body IS DISTINCT FROM OLD.body THEN
          RAISE EXCEPTION 'note body cannot change';
        END IF;
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.party_id IS DISTINCT FROM OLD.party_id
          OR NEW.author_membership_id IS DISTINCT FROM OLD.author_membership_id
          OR NEW.visibility IS DISTINCT FROM OLD.visibility THEN
          RAISE EXCEPTION 'note identity cannot change';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER party_notes_body_identity_immutable
        BEFORE UPDATE ON party_notes
        FOR EACH ROW
        EXECUTE FUNCTION party_notes_prevent_body_or_identity_change();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS party_notes_body_identity_immutable ON party_notes;
      DROP FUNCTION IF EXISTS party_notes_prevent_body_or_identity_change();
    SQL
    drop_table :party_notes
  end
end
