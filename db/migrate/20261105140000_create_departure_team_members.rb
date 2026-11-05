# frozen_string_literal: true

# Slice 1 step 2 (ACC-09, OPS-12, ADR 0016): the Departure team replaces the
# responsible office and responsible user. Each Departure's responsible user
# joins its team as the default task owner; the office is dropped. Team
# membership routes work only and grants nothing.
class CreateDepartureTeamMembers < ActiveRecord::Migration[8.1]
  def up
    unless index_exists?(:departures, %i[id agency_id], unique: true)
      add_index :departures, %i[id agency_id], unique: true, name: "index_departures_on_id_and_agency_id"
    end

    create_table :departure_team_members, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :agency_user_id, null: false
      table.boolean :default_task_owner, null: false, default: false
      table.timestamps

      table.index %i[departure_id agency_user_id], unique: true, name: "index_departure_team_members_on_departure_and_user"
      table.index :departure_id, unique: true, where: "default_task_owner", name: "index_departure_team_members_one_default_owner"
      table.index %i[agency_id agency_user_id], name: "index_departure_team_members_on_agency_and_user"
    end
    add_foreign_key :departure_team_members, :agencies, column: :agency_id, name: "fk_departure_team_members_agency"
    execute <<~SQL
      ALTER TABLE departure_team_members
        ADD CONSTRAINT fk_departure_team_members_departure_same_agency
        FOREIGN KEY (departure_id, agency_id) REFERENCES departures (id, agency_id),
        ADD CONSTRAINT fk_departure_team_members_user_same_agency
        FOREIGN KEY (agency_user_id, agency_id) REFERENCES agency_users (id, agency_id);

      INSERT INTO departure_team_members (agency_id, departure_id, agency_user_id, default_task_owner, created_at, updated_at)
      SELECT agency_id, id, responsible_agency_user_id, true, now(), now()
      FROM departures
      WHERE responsible_agency_user_id IS NOT NULL;
    SQL

    remove_check_constraint :departures, name: "departures_ready_to_sell_completeness"
    add_check_constraint :departures, <<~SQL.squish, name: "departures_ready_to_sell_completeness"
      sales_status = 'draft'
      OR (
        name IS NOT NULL AND btrim(name) <> ''
        AND starts_on IS NOT NULL
        AND ends_on IS NOT NULL
        AND time_zone IS NOT NULL AND btrim(time_zone) <> ''
        AND operating_currency IS NOT NULL
      )
    SQL
    remove_foreign_key :departures, name: "departures_agency_user_agency_fk"
    remove_foreign_key :departures, name: "departures_office_agency_fk"
    remove_index :departures, name: "index_departures_on_agency_office_starts_on_id"
    remove_index :departures, name: "index_departures_on_agency_user_starts_on_id"
    remove_column :departures, :responsible_office_id
    remove_column :departures, :responsible_agency_user_id
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
