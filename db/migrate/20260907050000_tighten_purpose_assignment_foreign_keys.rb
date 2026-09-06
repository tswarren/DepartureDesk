class TightenPurposeAssignmentForeignKeys < ActiveRecord::Migration[8.1]
  def up
    add_index :contact_point_purpose_assignments,
      [ :id, :agency_id ],
      unique: true,
      name: "index_cppa_on_id_and_agency_id"
    add_index :relationship_purpose_assignments,
      [ :id, :agency_id ],
      unique: true,
      name: "index_rpa_on_id_and_agency_id"
    add_index :party_contact_points,
      [ :id, :party_id, :agency_id, :contact_kind ],
      unique: true,
      name: "index_party_contact_points_on_id_party_agency_and_kind"
    add_index :party_relationships,
      [ :id, :related_party_id, :agency_id ],
      unique: true,
      name: "index_party_relationships_on_id_related_party_and_agency"

    execute <<~SQL
      ALTER TABLE contact_point_purpose_assignments
        DROP CONSTRAINT cppa_superseded_by_fk;
      ALTER TABLE contact_point_purpose_assignments
        DROP CONSTRAINT cppa_contact_kind_same_agency_fk;
      ALTER TABLE contact_point_purpose_assignments
        ADD CONSTRAINT cppa_contact_point_owner_fk
        FOREIGN KEY (contact_point_id, party_id, agency_id, contact_kind)
        REFERENCES party_contact_points (id, party_id, agency_id, contact_kind);
      ALTER TABLE contact_point_purpose_assignments
        ADD CONSTRAINT cppa_superseded_by_fk
        FOREIGN KEY (superseded_by_assignment_id, agency_id)
        REFERENCES contact_point_purpose_assignments (id, agency_id);

      ALTER TABLE relationship_purpose_assignments
        DROP CONSTRAINT rpa_superseded_by_fk;
      ALTER TABLE relationship_purpose_assignments
        DROP CONSTRAINT rpa_relationship_same_agency_fk;
      ALTER TABLE relationship_purpose_assignments
        DROP CONSTRAINT rpa_organization_party_same_agency_fk;
      ALTER TABLE relationship_purpose_assignments
        ADD CONSTRAINT rpa_relationship_owner_fk
        FOREIGN KEY (relationship_id, organization_party_id, agency_id)
        REFERENCES party_relationships (id, related_party_id, agency_id);
      ALTER TABLE relationship_purpose_assignments
        ADD CONSTRAINT rpa_organization_party_fk
        FOREIGN KEY (organization_party_id, agency_id)
        REFERENCES organizations (party_id, agency_id);
      ALTER TABLE relationship_purpose_assignments
        ADD CONSTRAINT rpa_superseded_by_fk
        FOREIGN KEY (superseded_by_assignment_id, agency_id)
        REFERENCES relationship_purpose_assignments (id, agency_id);
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE contact_point_purpose_assignments
        DROP CONSTRAINT cppa_superseded_by_fk;
      ALTER TABLE contact_point_purpose_assignments
        DROP CONSTRAINT cppa_contact_point_owner_fk;
      ALTER TABLE contact_point_purpose_assignments
        ADD CONSTRAINT cppa_contact_kind_same_agency_fk
        FOREIGN KEY (contact_point_id, agency_id, contact_kind)
        REFERENCES party_contact_points (id, agency_id, contact_kind);
      ALTER TABLE contact_point_purpose_assignments
        ADD CONSTRAINT cppa_superseded_by_fk
        FOREIGN KEY (superseded_by_assignment_id)
        REFERENCES contact_point_purpose_assignments (id);

      ALTER TABLE relationship_purpose_assignments
        DROP CONSTRAINT rpa_superseded_by_fk;
      ALTER TABLE relationship_purpose_assignments
        DROP CONSTRAINT rpa_relationship_owner_fk;
      ALTER TABLE relationship_purpose_assignments
        DROP CONSTRAINT rpa_organization_party_fk;
      ALTER TABLE relationship_purpose_assignments
        ADD CONSTRAINT rpa_relationship_same_agency_fk
        FOREIGN KEY (relationship_id, agency_id)
        REFERENCES party_relationships (id, agency_id);
      ALTER TABLE relationship_purpose_assignments
        ADD CONSTRAINT rpa_organization_party_same_agency_fk
        FOREIGN KEY (organization_party_id, agency_id)
        REFERENCES parties (id, agency_id);
      ALTER TABLE relationship_purpose_assignments
        ADD CONSTRAINT rpa_superseded_by_fk
        FOREIGN KEY (superseded_by_assignment_id)
        REFERENCES relationship_purpose_assignments (id);
    SQL

    remove_index :party_relationships, name: "index_party_relationships_on_id_related_party_and_agency"
    remove_index :party_contact_points, name: "index_party_contact_points_on_id_party_agency_and_kind"
    remove_index :relationship_purpose_assignments, name: "index_rpa_on_id_and_agency_id"
    remove_index :contact_point_purpose_assignments, name: "index_cppa_on_id_and_agency_id"
  end
end
