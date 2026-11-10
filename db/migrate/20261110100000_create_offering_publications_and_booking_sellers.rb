# frozen_string_literal: true

# Slice 1 step 9a (DEP-07 to DEP-09, ACC-18, FIN-05, D-68, D-78, D-99; step
# 9 plan questions 4, 6 and 7): an offering's publications to reseller
# channels (one channel per reseller relationship in Slice 1), a booking's
# owner and seller of record as separate facts, and who created a client or
# traveler.
class CreateOfferingPublicationsAndBookingSellers < ActiveRecord::Migration[8.1]
  def up
    create_table :offering_publications, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :offering_id, null: false
      table.uuid :reseller_id, null: false
      table.datetime :published_at, null: false
      table.uuid :published_by_id, null: false
      table.datetime :withdrawn_at
      table.uuid :withdrawn_by_id
      table.timestamps

      table.index %i[id agency_id], unique: true, name: "index_offering_publications_on_id_and_agency_id"
      table.index %i[offering_id reseller_id], unique: true, where: "withdrawn_at IS NULL", name: "index_offering_publications_one_open_per_channel"
      table.index %i[reseller_id withdrawn_at], name: "index_offering_publications_on_reseller"
      table.check_constraint "(withdrawn_at IS NULL) = (withdrawn_by_id IS NULL)", name: "offering_publications_withdrawn_pair"
      table.check_constraint "withdrawn_at IS NULL OR withdrawn_at >= published_at", name: "offering_publications_withdrawn_after_published"
    end

    change_table :client_bookings, bulk: true do |table|
      table.uuid :owner_reseller_id
      table.string :seller_kind, null: false, default: "agency"
      table.uuid :seller_reseller_id
      table.index :owner_reseller_id, name: "index_client_bookings_on_owner_reseller", where: "owner_reseller_id IS NOT NULL"
    end

    add_column :clients, :created_by_id, :uuid
    add_column :travelers, :created_by_id, :uuid

    execute <<~SQL
      ALTER TABLE offering_publications
        ADD CONSTRAINT fk_offering_publications_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_offering_publications_offering_same_agency FOREIGN KEY (offering_id, agency_id) REFERENCES offerings (id, agency_id),
        ADD CONSTRAINT fk_offering_publications_reseller_same_agency FOREIGN KEY (reseller_id, agency_id) REFERENCES resellers (id, agency_id),
        ADD CONSTRAINT fk_offering_publications_publisher_same_agency FOREIGN KEY (published_by_id, agency_id) REFERENCES agency_users (id, agency_id),
        ADD CONSTRAINT fk_offering_publications_withdrawer_same_agency FOREIGN KEY (withdrawn_by_id, agency_id) REFERENCES agency_users (id, agency_id);

      -- DEP-07 to DEP-09: a publication is a dated fact. Only its withdrawal is
      -- ever written after it is made, once; a new publication is a new row.
      CREATE FUNCTION public.reject_offering_publication_mutation() RETURNS trigger
          LANGUAGE plpgsql AS $$
      BEGIN
        IF TG_OP = 'DELETE' THEN
          RAISE EXCEPTION 'offering_publications rows cannot be deleted';
        END IF;
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.offering_id IS DISTINCT FROM OLD.offering_id
          OR NEW.reseller_id IS DISTINCT FROM OLD.reseller_id
          OR NEW.published_at IS DISTINCT FROM OLD.published_at
          OR NEW.published_by_id IS DISTINCT FROM OLD.published_by_id
          OR OLD.withdrawn_at IS NOT NULL THEN
          RAISE EXCEPTION 'an offering publication only records its withdrawal, once';
        END IF;
        RETURN NEW;
      END;
      $$;
      CREATE TRIGGER offering_publications_reject_mutation BEFORE DELETE OR UPDATE ON public.offering_publications
        FOR EACH ROW EXECUTE FUNCTION public.reject_offering_publication_mutation();

      -- ACC-18, FIN-05: the owner and the seller of record are each the agency
      -- or one of its resellers, independently.
      ALTER TABLE client_bookings
        DROP CONSTRAINT client_bookings_owner_kind,
        ADD CONSTRAINT client_bookings_owner_kind CHECK (owner_kind IN ('agency', 'reseller')),
        ADD CONSTRAINT client_bookings_owner_reseller CHECK ((owner_kind = 'reseller') = (owner_reseller_id IS NOT NULL)),
        ADD CONSTRAINT client_bookings_seller_kind CHECK (seller_kind IN ('agency', 'reseller')),
        ADD CONSTRAINT client_bookings_seller_reseller CHECK ((seller_kind = 'reseller') = (seller_reseller_id IS NOT NULL)),
        ADD CONSTRAINT fk_client_bookings_owner_reseller_same_agency FOREIGN KEY (owner_reseller_id, agency_id) REFERENCES resellers (id, agency_id),
        ADD CONSTRAINT fk_client_bookings_seller_reseller_same_agency FOREIGN KEY (seller_reseller_id, agency_id) REFERENCES resellers (id, agency_id);

      -- D-78: who created a profile, so staff can review reseller-created ones.
      -- Shipped rows have no recorded creator, so the column is nullable.
      ALTER TABLE clients
        ADD CONSTRAINT fk_clients_creator_same_agency FOREIGN KEY (created_by_id, agency_id) REFERENCES agency_users (id, agency_id);
      ALTER TABLE travelers
        ADD CONSTRAINT fk_travelers_creator_same_agency FOREIGN KEY (created_by_id, agency_id) REFERENCES agency_users (id, agency_id);
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
