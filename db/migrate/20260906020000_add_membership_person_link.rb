class AddMembershipPersonLink < ActiveRecord::Migration[8.1]
  def up
    add_column :agency_memberships, :person_party_id, :uuid

    execute <<~SQL
      CREATE TEMPORARY TABLE membership_people AS
      SELECT
        memberships.id AS membership_id,
        uuidv7() AS party_id,
        memberships.agency_id,
        btrim(users.first_name) AS given_name,
        btrim(users.last_name) AS family_name,
        NULLIF(btrim(users.preferred_name), '') AS preferred_name
      FROM agency_memberships AS memberships
      INNER JOIN users ON users.id = memberships.user_id
      WHERE memberships.person_party_id IS NULL;
    SQL

    execute <<~SQL
      INSERT INTO parties (
        id, agency_id, party_kind, display_name, sort_name, status,
        lock_version, created_at, updated_at
      )
      SELECT
        party_id,
        agency_id,
        'person',
        CASE
          WHEN preferred_name IS NOT NULL THEN preferred_name || ' ' || family_name
          ELSE given_name || ' ' || family_name
        END,
        family_name || ', ' || given_name,
        'active',
        0,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
      FROM membership_people;
    SQL

    execute <<~SQL
      INSERT INTO people (
        party_id, agency_id, given_name, family_name, preferred_name,
        lock_version, created_at, updated_at
      )
      SELECT
        party_id,
        agency_id,
        given_name,
        family_name,
        preferred_name,
        0,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
      FROM membership_people;
    SQL

    execute <<~SQL
      UPDATE agency_memberships
      SET person_party_id = membership_people.party_id
      FROM membership_people
      WHERE agency_memberships.id = membership_people.membership_id;
    SQL

    execute "DROP TABLE membership_people"

    unlinked = select_value("SELECT COUNT(*) FROM agency_memberships WHERE person_party_id IS NULL")
    if unlinked.to_i.positive?
      raise "Assign person_party_id to remaining memberships before adding NOT NULL (#{unlinked} remaining)"
    end

    change_column_null :agency_memberships, :person_party_id, false

    add_index :agency_memberships,
      [ :agency_id, :person_party_id ],
      unique: true,
      name: "index_agency_memberships_on_agency_id_and_person_party_id"
    add_index :agency_memberships,
      :person_party_id,
      name: "index_agency_memberships_on_person_party_id"

    execute <<~SQL
      ALTER TABLE agency_memberships
        ADD CONSTRAINT agency_memberships_person_party_same_agency_fk
        FOREIGN KEY (person_party_id, agency_id) REFERENCES people (party_id, agency_id);
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE agency_memberships
        DROP CONSTRAINT agency_memberships_person_party_same_agency_fk;
    SQL
    remove_index :agency_memberships, name: "index_agency_memberships_on_person_party_id"
    remove_index :agency_memberships, name: "index_agency_memberships_on_agency_id_and_person_party_id"
    remove_column :agency_memberships, :person_party_id
  end
end
