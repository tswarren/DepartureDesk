# frozen_string_literal: true

class CreateM4cPackages < ActiveRecord::Migration[8.1]
  VERSION_STATUSES = %w[draft abandoned published superseded retired].freeze
  INCLUSION_PLACEMENTS = %w[included optional].freeze
  INCLUSION_ORIGINS = %w[inline_create adopted_draft published_reusable].freeze

  def up
    create_packages
    create_package_versions
    add_owning_package_version
    create_package_inclusions
    create_triggers
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS package_inclusions_reject_non_draft_mutation ON public.package_inclusions;
      DROP TRIGGER IF EXISTS package_inclusions_reject_owner_change ON public.package_inclusions;
      DROP TRIGGER IF EXISTS package_inclusions_validate_origin ON public.package_inclusions;
      DROP TRIGGER IF EXISTS package_inclusions_validate_ownership_match ON public.package_inclusions;
      DROP TRIGGER IF EXISTS service_offer_versions_validate_ownership_match ON public.service_offer_versions;
      DROP TRIGGER IF EXISTS service_offer_versions_enforce_package_ownership ON public.service_offer_versions;
      DROP TRIGGER IF EXISTS package_versions_reject_invalid_lifecycle ON public.package_versions;
      DROP TRIGGER IF EXISTS package_versions_reject_owner_change ON public.package_versions;
      DROP TRIGGER IF EXISTS packages_reject_owner_change ON public.packages;
      DROP FUNCTION IF EXISTS reject_non_draft_package_version_definition_mutation();
      DROP FUNCTION IF EXISTS reject_package_inclusion_owner_change();
      DROP FUNCTION IF EXISTS validate_package_inclusion_origin();
      DROP FUNCTION IF EXISTS validate_package_ownership_inclusion_match();
      DROP FUNCTION IF EXISTS enforce_service_offer_version_package_ownership();
      DROP FUNCTION IF EXISTS reject_invalid_package_version_lifecycle();
      DROP FUNCTION IF EXISTS reject_package_version_owner_change();
      DROP FUNCTION IF EXISTS reject_package_owner_change();
    SQL

    drop_table :package_inclusions
    remove_index :service_offer_versions, name: "index_service_offer_versions_on_owning_package_version"
    remove_foreign_key :service_offer_versions, name: "service_offer_versions_owning_package_version_fk"
    remove_column :service_offer_versions, :owning_package_version_id
    drop_table :package_versions
    drop_table :packages
  end

  private

  def create_packages
    create_table :packages, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :departure_id, null: false
      table.string :name, null: false, limit: 160
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :packages, [ :id, :agency_id ],
      unique: true, name: "index_packages_on_id_and_agency_id"
    add_index :packages, [ :id, :departure_id, :agency_id ],
      unique: true, name: "index_packages_on_id_departure_agency"
    add_index :packages, [ :agency_id, :departure_id, :name, :id ],
      name: "index_packages_on_departure_list"

    add_foreign_key :packages, :departures,
      column: [ :departure_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "packages_departure_agency_fk"

    add_check_constraint :packages,
      "btrim(name) <> '' AND char_length(name) <= 160",
      name: "packages_name"
    add_check_constraint :packages,
      "lock_version >= 0",
      name: "packages_lock_version"
  end

  def create_package_versions
    create_table :package_versions, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :departure_id, null: false
      table.uuid :package_id, null: false
      table.integer :version_number, null: false
      table.string :status, null: false, default: "draft"
      table.timestamptz :abandoned_at
      table.string :abandoned_reason, limit: 500
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :package_versions, [ :id, :agency_id ],
      unique: true, name: "index_package_versions_on_id_and_agency"
    add_index :package_versions, [ :id, :departure_id, :agency_id ],
      unique: true, name: "index_package_versions_on_id_departure_agency"
    add_index :package_versions,
      [ :id, :package_id, :departure_id, :agency_id ],
      unique: true, name: "index_package_versions_on_full_owner"
    add_index :package_versions, [ :package_id, :version_number ],
      unique: true, name: "index_package_versions_on_number"
    add_index :package_versions, :package_id,
      unique: true, where: "status = 'draft'",
      name: "index_package_versions_one_draft"

    add_foreign_key :package_versions, :packages,
      column: [ :package_id, :departure_id, :agency_id ],
      primary_key: [ :id, :departure_id, :agency_id ],
      name: "package_versions_package_fk"

    add_check_constraint :package_versions,
      "version_number > 0",
      name: "package_versions_number_positive"
    add_check_constraint :package_versions,
      "status IN ('#{VERSION_STATUSES.join("', '")}')",
      name: "package_versions_status"
    add_check_constraint :package_versions,
      "(status = 'abandoned' AND abandoned_at IS NOT NULL AND abandoned_reason IS NOT NULL) OR " \
      "(status <> 'abandoned' AND abandoned_at IS NULL AND abandoned_reason IS NULL)",
      name: "package_versions_abandoned_pair"
    add_check_constraint :package_versions,
      "abandoned_reason IS NULL OR (btrim(abandoned_reason) <> '' AND char_length(abandoned_reason) <= 500)",
      name: "package_versions_reason"
    add_check_constraint :package_versions,
      "lock_version >= 0",
      name: "package_versions_lock_version"
  end

  def add_owning_package_version
    add_column :service_offer_versions, :owning_package_version_id, :uuid

    add_index :service_offer_versions, :owning_package_version_id,
      name: "index_service_offer_versions_on_owning_package_version"

    add_foreign_key :service_offer_versions, :package_versions,
      column: [ :owning_package_version_id, :departure_id, :agency_id ],
      primary_key: [ :id, :departure_id, :agency_id ],
      name: "service_offer_versions_owning_package_version_fk"
  end

  def create_package_inclusions
    create_table :package_inclusions, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :departure_id, null: false
      table.uuid :package_id, null: false
      table.uuid :package_version_id, null: false
      table.uuid :service_offer_id, null: false
      table.uuid :service_offer_version_id, null: false
      table.string :placement, null: false, default: "included"
      table.string :origin, null: false
      table.integer :position, null: false
      table.timestamps null: false
    end

    add_index :package_inclusions, [ :id, :agency_id ],
      unique: true, name: "index_package_inclusions_on_id_and_agency"
    add_index :package_inclusions,
      [ :id, :package_version_id, :package_id, :departure_id, :agency_id ],
      unique: true, name: "index_package_inclusions_on_full_owner"
    add_index :package_inclusions, [ :package_version_id, :position ],
      unique: true, name: "index_package_inclusions_on_position"
    add_index :package_inclusions, [ :package_version_id, :service_offer_version_id ],
      unique: true, name: "index_package_inclusions_on_version_offer"
    execute <<~SQL
      CREATE UNIQUE INDEX index_package_inclusions_one_draft_service
        ON package_inclusions (service_offer_version_id)
        WHERE origin IN ('inline_create', 'adopted_draft');
    SQL

    add_foreign_key :package_inclusions, :package_versions,
      column: [ :package_version_id, :package_id, :departure_id, :agency_id ],
      primary_key: [ :id, :package_id, :departure_id, :agency_id ],
      name: "package_inclusions_package_version_fk"
    add_foreign_key :package_inclusions, :service_offer_versions,
      column: [ :service_offer_version_id, :service_offer_id, :departure_id, :agency_id ],
      primary_key: [ :id, :service_offer_id, :departure_id, :agency_id ],
      name: "package_inclusions_service_offer_version_fk"

    add_check_constraint :package_inclusions,
      "placement IN ('#{INCLUSION_PLACEMENTS.join("', '")}')",
      name: "package_inclusions_placement"
    add_check_constraint :package_inclusions,
      "origin IN ('#{INCLUSION_ORIGINS.join("', '")}')",
      name: "package_inclusions_origin"
    add_check_constraint :package_inclusions,
      "position > 0",
      name: "package_inclusions_position"
  end

  def create_triggers
    execute <<~SQL
      CREATE FUNCTION reject_package_owner_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id THEN
          RAISE EXCEPTION 'package owner is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER packages_reject_owner_change
        BEFORE UPDATE ON public.packages
        FOR EACH ROW EXECUTE FUNCTION reject_package_owner_change();

      CREATE FUNCTION reject_package_version_owner_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.package_id IS DISTINCT FROM OLD.package_id
          OR NEW.version_number IS DISTINCT FROM OLD.version_number THEN
          RAISE EXCEPTION 'package version owner is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER package_versions_reject_owner_change
        BEFORE UPDATE ON public.package_versions
        FOR EACH ROW EXECUTE FUNCTION reject_package_version_owner_change();

      CREATE FUNCTION reject_invalid_package_version_lifecycle() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
          IF NOT (OLD.status = 'draft' AND NEW.status = 'abandoned') THEN
            RAISE EXCEPTION 'package version status transition from % to % is not permitted',
              OLD.status, NEW.status;
          END IF;
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER package_versions_reject_invalid_lifecycle
        BEFORE UPDATE ON public.package_versions
        FOR EACH ROW EXECUTE FUNCTION reject_invalid_package_version_lifecycle();

      CREATE FUNCTION enforce_service_offer_version_package_ownership() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE
        package_agency_id uuid;
        package_departure_id uuid;
        package_status text;
        offer_status text;
      BEGIN
        IF TG_OP = 'UPDATE' THEN
        IF NEW.owning_package_version_id IS NOT DISTINCT FROM OLD.owning_package_version_id THEN
          RETURN NEW;
        END IF;

        IF OLD.owning_package_version_id IS NOT NULL
           AND NEW.owning_package_version_id IS NOT NULL
           AND NEW.owning_package_version_id IS DISTINCT FROM OLD.owning_package_version_id THEN
          RAISE EXCEPTION 'package ownership cannot be reassigned to a different package version';
        END IF;
      END IF;

      IF NEW.owning_package_version_id IS NOT NULL THEN
        SELECT agency_id, departure_id, status
          INTO package_agency_id, package_departure_id, package_status
          FROM public.package_versions
         WHERE id = NEW.owning_package_version_id;

        IF package_agency_id IS DISTINCT FROM NEW.agency_id
           OR package_departure_id IS DISTINCT FROM NEW.departure_id THEN
          RAISE EXCEPTION 'package-owned service version must share agency and departure';
        END IF;

        IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.owning_package_version_id IS NULL) THEN
          offer_status := NEW.status;
          IF offer_status IS DISTINCT FROM 'draft' OR package_status IS DISTINCT FROM 'draft' THEN
            RAISE EXCEPTION 'package ownership can be set only while both versions are draft';
          END IF;
        END IF;
      END IF;

        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER service_offer_versions_enforce_package_ownership
        BEFORE INSERT OR UPDATE ON public.service_offer_versions
        FOR EACH ROW EXECUTE FUNCTION enforce_service_offer_version_package_ownership();

      CREATE FUNCTION validate_package_ownership_inclusion_match() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE
        owner_id uuid;
        version_id uuid;
        matching integer;
      BEGIN
        IF TG_TABLE_NAME = 'service_offer_versions' THEN
          owner_id := NEW.owning_package_version_id;
          version_id := NEW.id;
          IF owner_id IS NULL THEN
            RETURN NEW;
          END IF;
        ELSIF TG_OP = 'DELETE' THEN
          owner_id := OLD.package_version_id;
          version_id := OLD.service_offer_version_id;
        ELSE
          owner_id := NEW.package_version_id;
          version_id := NEW.service_offer_version_id;
        END IF;

        SELECT COUNT(*) INTO matching
          FROM public.service_offer_versions
         WHERE id = version_id
           AND owning_package_version_id IS NOT NULL;

        IF matching = 0 THEN
          RETURN COALESCE(NEW, OLD);
        END IF;

        SELECT COUNT(*) INTO matching
          FROM public.package_inclusions
         WHERE package_version_id = (
                 SELECT owning_package_version_id
                   FROM public.service_offer_versions
                  WHERE id = version_id
               )
           AND service_offer_version_id = version_id;

        IF matching = 0 THEN
          RAISE EXCEPTION 'package-owned service version requires a matching inclusion';
        END IF;

        RETURN COALESCE(NEW, OLD);
      END;
      $$;

      CREATE CONSTRAINT TRIGGER service_offer_versions_validate_ownership_match
        AFTER INSERT OR UPDATE OF owning_package_version_id ON public.service_offer_versions
        DEFERRABLE INITIALLY DEFERRED
        FOR EACH ROW EXECUTE FUNCTION validate_package_ownership_inclusion_match();

      CREATE CONSTRAINT TRIGGER package_inclusions_validate_ownership_match
        AFTER INSERT OR UPDATE OR DELETE ON public.package_inclusions
        DEFERRABLE INITIALLY DEFERRED
        FOR EACH ROW EXECUTE FUNCTION validate_package_ownership_inclusion_match();

      CREATE FUNCTION validate_package_inclusion_origin() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE
        offer_status text;
        owner_id uuid;
      BEGIN
        SELECT status, owning_package_version_id
          INTO offer_status, owner_id
          FROM public.service_offer_versions
         WHERE id = NEW.service_offer_version_id;

        IF NEW.origin = 'published_reusable' THEN
          IF offer_status IS DISTINCT FROM 'published' THEN
            RAISE EXCEPTION 'published reusable inclusion requires a published service offer version';
          END IF;
          IF owner_id IS NOT NULL THEN
            RAISE EXCEPTION 'published reusable inclusion cannot own the service offer version';
          END IF;
        ELSE
          IF TG_OP = 'INSERT' AND offer_status IS DISTINCT FROM 'draft' THEN
            RAISE EXCEPTION 'inline or adopted inclusion requires a draft service offer version';
          END IF;
          IF owner_id IS DISTINCT FROM NEW.package_version_id THEN
            RAISE EXCEPTION 'inline or adopted inclusion must match package ownership';
          END IF;
        END IF;

        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER package_inclusions_validate_origin
        BEFORE INSERT OR UPDATE ON public.package_inclusions
        FOR EACH ROW EXECUTE FUNCTION validate_package_inclusion_origin();

      CREATE FUNCTION reject_package_inclusion_owner_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.package_id IS DISTINCT FROM OLD.package_id
          OR NEW.package_version_id IS DISTINCT FROM OLD.package_version_id
          OR NEW.service_offer_id IS DISTINCT FROM OLD.service_offer_id
          OR NEW.service_offer_version_id IS DISTINCT FROM OLD.service_offer_version_id THEN
          RAISE EXCEPTION 'package inclusion owner is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER package_inclusions_reject_owner_change
        BEFORE UPDATE ON public.package_inclusions
        FOR EACH ROW EXECUTE FUNCTION reject_package_inclusion_owner_change();

      CREATE FUNCTION reject_non_draft_package_version_definition_mutation() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE
        version_id uuid;
        version_status text;
      BEGIN
        IF TG_OP = 'INSERT' THEN
          version_id := NEW.package_version_id;
        ELSE
          version_id := OLD.package_version_id;
        END IF;

        SELECT status INTO version_status
          FROM public.package_versions
         WHERE id = version_id
         FOR SHARE;

        IF version_status IS DISTINCT FROM 'draft' THEN
          RAISE EXCEPTION 'exact-version definitions are immutable after leaving draft';
        END IF;

        IF TG_OP = 'DELETE' THEN
          RETURN OLD;
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER package_inclusions_reject_non_draft_mutation
        BEFORE INSERT OR UPDATE OR DELETE ON public.package_inclusions
        FOR EACH ROW EXECUTE FUNCTION reject_non_draft_package_version_definition_mutation();
    SQL
  end
end
