class CreatePartyRelationships < ActiveRecord::Migration[8.1]
  def up
    create_table :party_relationships,
      id: :uuid,
      default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :origin_party_id, null: false
      table.string :origin_party_kind, null: false
      table.uuid :related_party_id, null: false
      table.string :related_party_kind, null: false
      table.string :relationship_kind, null: false
      table.string :relationship_label
      table.string :title
      table.date :effective_from
      table.date :effective_until
      table.string :record_status, null: false, default: "valid"
      table.uuid :superseded_by_relationship_id
      table.timestamptz :corrected_at
      table.uuid :corrected_by_membership_id
      table.string :correction_reason
      table.timestamptz :ended_at
      table.uuid :ended_by_membership_id
      table.string :ending_reason
      table.string :source
      table.string :notes
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :party_relationships,
      [ :id, :agency_id ],
      unique: true,
      name: "index_party_relationships_on_id_and_agency_id"
    add_index :party_relationships,
      [ :origin_party_id, :agency_id ],
      name: "index_party_relationships_on_origin_party"
    add_index :party_relationships,
      [ :related_party_id, :agency_id ],
      name: "index_party_relationships_on_related_party"

    add_check_constraint :party_relationships,
      "origin_party_id <> related_party_id",
      name: "party_relationships_no_self"
    add_check_constraint :party_relationships,
      "relationship_kind IN ('household_member', 'family', 'organization_affiliation', 'organization_contact', 'parent_organization', 'service_provider_for')",
      name: "party_relationships_kind_valid"
    add_check_constraint :party_relationships,
      "record_status IN ('valid', 'superseded', 'voided')",
      name: "party_relationships_record_status_valid"
    add_check_constraint :party_relationships,
      "effective_until IS NULL OR effective_from IS NULL OR effective_until > effective_from",
      name: "party_relationships_range_order"
    add_check_constraint :party_relationships,
      "lock_version >= 0",
      name: "party_relationships_lock_version_nonnegative"
    add_check_constraint :party_relationships,
      <<~SQL.squish,
        (relationship_kind = 'household_member' AND origin_party_kind = 'person' AND related_party_kind = 'household')
        OR (relationship_kind = 'family' AND origin_party_kind = 'person' AND related_party_kind = 'person')
        OR (relationship_kind = 'organization_affiliation' AND origin_party_kind = 'person' AND related_party_kind = 'organization')
        OR (relationship_kind = 'organization_contact' AND origin_party_kind = 'person' AND related_party_kind = 'organization')
        OR (relationship_kind = 'parent_organization' AND origin_party_kind = 'organization' AND related_party_kind = 'organization')
        OR (relationship_kind = 'service_provider_for' AND origin_party_kind = 'organization' AND related_party_kind = 'organization')
      SQL
      name: "party_relationships_kind_pair_valid"
    add_check_constraint :party_relationships,
      <<~SQL.squish,
        (relationship_kind = 'family' AND relationship_label IN ('parent_of', 'child_of', 'guardian_of', 'dependent_of', 'spouse_of', 'partner_of', 'other_family'))
        OR (relationship_kind = 'organization_affiliation' AND relationship_label IN ('employee', 'contractor', 'owner', 'member', 'representative', 'other'))
        OR (relationship_kind IN ('household_member', 'organization_contact', 'parent_organization', 'service_provider_for') AND relationship_label IS NULL)
      SQL
      name: "party_relationships_label_matches_kind"
    add_check_constraint :party_relationships,
      <<~SQL.squish,
        relationship_kind <> 'family'
        OR relationship_label NOT IN ('spouse_of', 'partner_of')
        OR origin_party_id < related_party_id
      SQL
      name: "party_relationships_spouse_canonical_order"
    add_check_constraint :party_relationships,
      <<~SQL.squish,
        (record_status = 'valid'
          AND superseded_by_relationship_id IS NULL
          AND corrected_at IS NULL
          AND corrected_by_membership_id IS NULL
          AND correction_reason IS NULL)
        OR
        (record_status = 'superseded'
          AND superseded_by_relationship_id IS NOT NULL
          AND corrected_at IS NOT NULL
          AND corrected_by_membership_id IS NOT NULL
          AND btrim(correction_reason) <> '')
        OR
        (record_status = 'voided'
          AND corrected_at IS NOT NULL
          AND corrected_by_membership_id IS NOT NULL
          AND btrim(correction_reason) <> '')
      SQL
      name: "pr_disposition_matches_status"
    add_check_constraint :party_relationships,
      <<~SQL.squish,
        (ended_at IS NULL AND ended_by_membership_id IS NULL AND ending_reason IS NULL)
        OR (ended_at IS NOT NULL AND ended_by_membership_id IS NOT NULL AND btrim(ending_reason) <> '' AND effective_until IS NOT NULL)
      SQL
      name: "pr_ending_complete"

    execute <<~SQL
      ALTER TABLE party_relationships
        ADD CONSTRAINT pr_origin_party_kind_same_agency_fk
        FOREIGN KEY (origin_party_id, agency_id, origin_party_kind)
        REFERENCES parties (id, agency_id, party_kind);
      ALTER TABLE party_relationships
        ADD CONSTRAINT pr_related_party_kind_same_agency_fk
        FOREIGN KEY (related_party_id, agency_id, related_party_kind)
        REFERENCES parties (id, agency_id, party_kind);
      ALTER TABLE party_relationships
        ADD CONSTRAINT pr_corrected_by_membership_fk
        FOREIGN KEY (corrected_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
      ALTER TABLE party_relationships
        ADD CONSTRAINT pr_ended_by_membership_fk
        FOREIGN KEY (ended_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
      ALTER TABLE party_relationships
        ADD CONSTRAINT pr_superseded_by_fk
        FOREIGN KEY (superseded_by_relationship_id, agency_id)
        REFERENCES party_relationships (id, agency_id);
    SQL

    execute <<~SQL
      ALTER TABLE party_relationships
        ADD CONSTRAINT pr_unique_valid_duplicate
        EXCLUDE USING gist (
          agency_id WITH =,
          origin_party_id WITH =,
          related_party_id WITH =,
          relationship_kind WITH =,
          COALESCE(relationship_label, '') WITH =,
          daterange(effective_from, effective_until, '[)') WITH &&
        )
        WHERE (record_status = 'valid');
      ALTER TABLE party_relationships
        ADD CONSTRAINT pr_unique_valid_spouse_pair
        EXCLUDE USING gist (
          agency_id WITH =,
          LEAST(origin_party_id, related_party_id) WITH =,
          GREATEST(origin_party_id, related_party_id) WITH =,
          relationship_label WITH =,
          daterange(effective_from, effective_until, '[)') WITH &&
        )
        WHERE (record_status = 'valid' AND relationship_kind = 'family' AND relationship_label IN ('spouse_of', 'partner_of'));
      ALTER TABLE party_relationships
        ADD CONSTRAINT pr_affiliation_contact_conflict
        EXCLUDE USING gist (
          agency_id WITH =,
          origin_party_id WITH =,
          related_party_id WITH =,
          daterange(effective_from, effective_until, '[)') WITH &&
        )
        WHERE (record_status = 'valid' AND relationship_kind IN ('organization_affiliation', 'organization_contact'));
      ALTER TABLE party_relationships
        ADD CONSTRAINT pr_one_valid_parent
        EXCLUDE USING gist (
          agency_id WITH =,
          origin_party_id WITH =,
          daterange(effective_from, effective_until, '[)') WITH &&
        )
        WHERE (record_status = 'valid' AND relationship_kind = 'parent_organization');
    SQL

    execute <<~SQL
      CREATE FUNCTION party_relationships_prevent_immutable_change() RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.origin_party_id IS DISTINCT FROM OLD.origin_party_id
          OR NEW.related_party_id IS DISTINCT FROM OLD.related_party_id
          OR NEW.origin_party_kind IS DISTINCT FROM OLD.origin_party_kind
          OR NEW.related_party_kind IS DISTINCT FROM OLD.related_party_kind
          OR NEW.relationship_kind IS DISTINCT FROM OLD.relationship_kind THEN
          RAISE EXCEPTION 'relationship identity cannot change';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER party_relationships_identity_immutable
        BEFORE UPDATE ON party_relationships
        FOR EACH ROW
        EXECUTE FUNCTION party_relationships_prevent_immutable_change();
    SQL

    create_purpose_assignments
  end

  def down
    drop_table :relationship_purpose_assignments
    execute <<~SQL
      DROP TRIGGER IF EXISTS party_relationships_identity_immutable ON party_relationships;
      DROP FUNCTION IF EXISTS party_relationships_prevent_immutable_change();
    SQL
    drop_table :party_relationships
  end

  private

  def create_purpose_assignments
    create_table :relationship_purpose_assignments,
      id: :uuid,
      default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :relationship_id, null: false
      table.uuid :organization_party_id, null: false
      table.string :purpose, null: false
      table.integer :priority, null: false
      table.date :effective_from
      table.date :effective_until
      table.string :record_status, null: false, default: "valid"
      table.uuid :superseded_by_assignment_id
      table.timestamptz :corrected_at
      table.uuid :corrected_by_membership_id
      table.string :correction_reason
      table.timestamptz :ended_at
      table.uuid :ended_by_membership_id
      table.string :ending_reason
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :relationship_purpose_assignments,
      [ :relationship_id, :agency_id ],
      name: "index_rpa_on_relationship"
    add_check_constraint :relationship_purpose_assignments,
      "purpose IN ('general', 'booking', 'accounting')",
      name: "rpa_purpose_valid"
    add_check_constraint :relationship_purpose_assignments,
      "priority >= 1",
      name: "rpa_priority_positive"
    add_check_constraint :relationship_purpose_assignments,
      "record_status IN ('valid', 'superseded', 'voided')",
      name: "rpa_record_status_valid"
    add_check_constraint :relationship_purpose_assignments,
      "effective_until IS NULL OR effective_from IS NULL OR effective_until > effective_from",
      name: "rpa_range_order"
    add_check_constraint :relationship_purpose_assignments,
      "lock_version >= 0",
      name: "rpa_lock_version_nonnegative"
    add_check_constraint :relationship_purpose_assignments,
      <<~SQL.squish,
        (record_status = 'valid'
          AND superseded_by_assignment_id IS NULL
          AND corrected_at IS NULL
          AND corrected_by_membership_id IS NULL
          AND correction_reason IS NULL)
        OR
        (record_status = 'superseded'
          AND superseded_by_assignment_id IS NOT NULL
          AND corrected_at IS NOT NULL
          AND corrected_by_membership_id IS NOT NULL
          AND btrim(correction_reason) <> '')
        OR
        (record_status = 'voided'
          AND corrected_at IS NOT NULL
          AND corrected_by_membership_id IS NOT NULL
          AND btrim(correction_reason) <> '')
      SQL
      name: "rpa_disposition_matches_status"
    add_check_constraint :relationship_purpose_assignments,
      <<~SQL.squish,
        (ended_at IS NULL AND ended_by_membership_id IS NULL AND ending_reason IS NULL)
        OR (ended_at IS NOT NULL AND ended_by_membership_id IS NOT NULL AND btrim(ending_reason) <> '' AND effective_until IS NOT NULL)
      SQL
      name: "rpa_ending_complete"

    execute <<~SQL
      ALTER TABLE relationship_purpose_assignments
        ADD CONSTRAINT rpa_relationship_same_agency_fk
        FOREIGN KEY (relationship_id, agency_id)
        REFERENCES party_relationships (id, agency_id);
      ALTER TABLE relationship_purpose_assignments
        ADD CONSTRAINT rpa_organization_party_same_agency_fk
        FOREIGN KEY (organization_party_id, agency_id)
        REFERENCES parties (id, agency_id);
      ALTER TABLE relationship_purpose_assignments
        ADD CONSTRAINT rpa_corrected_by_membership_fk
        FOREIGN KEY (corrected_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
      ALTER TABLE relationship_purpose_assignments
        ADD CONSTRAINT rpa_ended_by_membership_fk
        FOREIGN KEY (ended_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
      ALTER TABLE relationship_purpose_assignments
        ADD CONSTRAINT rpa_superseded_by_fk
        FOREIGN KEY (superseded_by_assignment_id)
        REFERENCES relationship_purpose_assignments (id);
      ALTER TABLE relationship_purpose_assignments
        ADD CONSTRAINT rpa_unique_valid_primary
        EXCLUDE USING gist (
          agency_id WITH =,
          organization_party_id WITH =,
          purpose WITH =,
          daterange(effective_from, effective_until, '[)') WITH &&
        )
        WHERE (record_status = 'valid' AND priority = 1);
    SQL
  end
end
