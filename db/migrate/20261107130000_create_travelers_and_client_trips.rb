# frozen_string_literal: true

# Slice 1 step 6a (CLT-02, CLT-05, CLT-06, CLT-09 to CLT-11, CLT-28, OVR-02,
# REF-04, D-94): traveler profiles, their links to clients, and Client Trips,
# each with one responsible client and at most one Departure, referenced at
# creation.
class CreateTravelersAndClientTrips < ActiveRecord::Migration[8.1]
  def up
    create_table :travelers, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.string :given_names
      table.string :middle_name
      table.string :surname
      table.string :suffix
      table.string :preferred_name
      table.date :date_of_birth
      table.string :gender
      table.string :email_address
      table.string :phone
      table.integer :lock_version, null: false, default: 0
      table.timestamps

      table.index %i[id agency_id], unique: true, name: "index_travelers_on_id_and_agency_id"
      table.index %i[agency_id surname given_names], name: "index_travelers_on_agency_and_name"
      # A profile saves with details missing (UI acceptance), but needs a name to be found.
      table.check_constraint "num_nonnulls(given_names, surname, preferred_name) >= 1", name: "travelers_some_name"
      table.check_constraint <<~SQL.squish, name: "travelers_name_lengths"
        (given_names IS NULL OR (btrim(given_names) <> '' AND char_length(given_names) <= 80))
        AND (middle_name IS NULL OR (btrim(middle_name) <> '' AND char_length(middle_name) <= 80))
        AND (surname IS NULL OR (btrim(surname) <> '' AND char_length(surname) <= 80))
        AND (suffix IS NULL OR (btrim(suffix) <> '' AND char_length(suffix) <= 20))
        AND (preferred_name IS NULL OR (btrim(preferred_name) <> '' AND char_length(preferred_name) <= 80))
      SQL
      table.check_constraint "date_of_birth IS NULL OR date_of_birth >= DATE '1900-01-01'", name: "travelers_date_of_birth"
      table.check_constraint "gender IS NULL OR gender IN ('female', 'male', 'unspecified')", name: "travelers_gender"
      table.check_constraint <<~SQL.squish, name: "travelers_contacts"
        (email_address IS NULL OR (email_address = lower(btrim(email_address)) AND email_address LIKE '%_@_%' AND char_length(email_address) <= 254))
        AND (phone IS NULL OR (btrim(phone) <> '' AND char_length(phone) <= 40))
      SQL
      table.check_constraint "lock_version >= 0", name: "travelers_lock_version"
    end

    create_table :traveler_links, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :traveler_id, null: false
      table.uuid :client_id, null: false
      table.string :relationship, null: false
      table.timestamps

      table.index %i[client_id traveler_id], unique: true, name: "index_traveler_links_one_per_client_and_traveler"
      table.index :traveler_id, name: "index_traveler_links_on_traveler"
      # CLT-11: a client has at most one Self traveler.
      table.index :client_id, unique: true, where: "relationship = 'self'", name: "index_traveler_links_one_self_per_client"
      table.check_constraint "relationship IN ('self', 'family_member', 'employee_or_member', 'other')", name: "traveler_links_relationship"
    end

    create_table :client_trips, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :client_id, null: false
      table.uuid :departure_id
      table.string :trip_reference, null: false
      table.integer :lock_version, null: false, default: 0
      table.timestamps

      table.index %i[agency_id trip_reference], unique: true, name: "index_client_trips_on_agency_and_reference"
      table.index %i[id agency_id], unique: true, name: "index_client_trips_on_id_and_agency_id"
      table.index :client_id, name: "index_client_trips_on_client"
      table.index :departure_id, name: "index_client_trips_on_departure"
      table.check_constraint "trip_reference ~ '^T-[0-9]{5,}$'", name: "client_trips_reference_format"
      table.check_constraint "lock_version >= 0", name: "client_trips_lock_version"
    end

    execute <<~SQL
      ALTER TABLE travelers
        ADD CONSTRAINT fk_travelers_agency FOREIGN KEY (agency_id) REFERENCES agencies (id);
      ALTER TABLE traveler_links
        ADD CONSTRAINT fk_traveler_links_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_traveler_links_traveler_same_agency FOREIGN KEY (traveler_id, agency_id) REFERENCES travelers (id, agency_id),
        ADD CONSTRAINT fk_traveler_links_client_same_agency FOREIGN KEY (client_id, agency_id) REFERENCES clients (id, agency_id);
      ALTER TABLE client_trips
        ADD CONSTRAINT fk_client_trips_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_client_trips_client_same_agency FOREIGN KEY (client_id, agency_id) REFERENCES clients (id, agency_id),
        ADD CONSTRAINT fk_client_trips_departure_same_agency FOREIGN KEY (departure_id, agency_id) REFERENCES departures (id, agency_id);

      CREATE TRIGGER travelers_reject_agency_change BEFORE UPDATE ON public.travelers
        FOR EACH ROW EXECUTE FUNCTION public.reject_directory_agency_change();

      -- CLT-11: Self links a person-backed client to the traveler who is that person.
      CREATE FUNCTION public.reject_self_link_to_organization() RETURNS trigger
          LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.relationship = 'self' AND EXISTS (SELECT 1 FROM clients WHERE id = NEW.client_id AND client_person_id IS NULL) THEN
          RAISE EXCEPTION 'only a person client can be linked as Self';
        END IF;
        RETURN NEW;
      END;
      $$;
      CREATE TRIGGER traveler_links_reject_self_organization BEFORE INSERT OR UPDATE ON public.traveler_links
        FOR EACH ROW EXECUTE FUNCTION public.reject_self_link_to_organization();

      -- REF-03: a trip's reference and agency never change.
      CREATE FUNCTION public.reject_client_trip_identity_change() RETURNS trigger
          LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id OR NEW.trip_reference IS DISTINCT FROM OLD.trip_reference THEN
          RAISE EXCEPTION 'client trip identity is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;
      CREATE TRIGGER client_trips_reject_identity_change BEFORE UPDATE ON public.client_trips
        FOR EACH ROW EXECUTE FUNCTION public.reject_client_trip_identity_change();
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
