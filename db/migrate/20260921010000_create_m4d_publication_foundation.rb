# frozen_string_literal: true

class CreateM4dPublicationFoundation < ActiveRecord::Migration[8.1]
  def up
    add_column :packages, :current_published_version_id, :uuid
    add_column :service_offers, :current_published_version_id, :uuid
    add_column :package_versions, :copied_from_version_id, :uuid
    add_column :service_offer_versions, :copied_from_version_id, :uuid
    add_column :package_versions, :published_at, :timestamptz
    add_column :service_offer_versions, :published_at, :timestamptz
    add_column :package_versions, :retired_at, :timestamptz
    add_column :service_offer_versions, :retired_at, :timestamptz

    create_table :package_version_sales_states, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.references :departure, null: false, type: :uuid
      table.references :package_version, null: false, type: :uuid, index: { unique: true }
      table.boolean :sales_enabled, null: false, default: true
      table.timestamps
    end

    create_table :service_offer_version_sales_states, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.references :departure, null: false, type: :uuid
      table.references :service_offer_version, null: false, type: :uuid,
        index: { unique: true, name: "index_so_version_sales_states_on_version_id" }
      table.boolean :sales_enabled, null: false, default: true
      table.timestamps
    end

    create_table :package_publication_manifests, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.references :departure, null: false, type: :uuid
      table.references :package_version, null: false, type: :uuid, index: { unique: true }
      table.references :actor_agency_user, null: true, type: :uuid
      table.timestamptz :published_at, null: false
      table.jsonb :fingerprint_json, null: false, default: {}
      table.timestamps
    end

    create_table :service_offer_publication_manifests, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.references :departure, null: false, type: :uuid
      table.references :service_offer_version, null: false, type: :uuid,
        index: { unique: true, name: "index_so_publication_manifests_on_version_id" }
      table.references :actor_agency_user, null: true, type: :uuid
      table.timestamptz :published_at, null: false
      table.jsonb :fingerprint_json, null: false, default: {}
      table.timestamps
    end

    create_table :package_publication_results, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.references :departure, null: false, type: :uuid
      table.references :agency_command_idempotency_key, null: false, type: :uuid,
        index: { unique: true, name: "index_package_publication_results_on_idempotency_key" }
      table.references :package_version, null: false, type: :uuid
      table.timestamps
    end

    add_index :package_publication_results, %i[id agency_id], unique: true,
      name: "index_package_publication_results_on_id_and_agency"

    create_table :package_publication_result_service_versions, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.references :package_publication_result, null: false, type: :uuid,
        index: { name: "index_pkg_pub_result_sovs_on_result_id" }
      table.references :service_offer_version, null: false, type: :uuid,
        index: { name: "index_pkg_pub_result_sovs_on_sov_id" }
      table.timestamps
    end

    add_index :package_publication_result_service_versions,
      %i[package_publication_result_id service_offer_version_id],
      unique: true,
      name: "index_pkg_pub_result_sovs_unique"

    add_foreign_key :packages, :package_versions,
      column: :current_published_version_id,
      name: "packages_current_published_version_fk"
    add_foreign_key :service_offers, :service_offer_versions,
      column: :current_published_version_id,
      name: "service_offers_current_published_version_fk"

    add_foreign_key :package_versions, :package_versions,
      column: :copied_from_version_id,
      name: "package_versions_copied_from_fk"
    add_foreign_key :service_offer_versions, :service_offer_versions,
      column: :copied_from_version_id,
      name: "service_offer_versions_copied_from_fk"

    add_foreign_key :package_version_sales_states, :package_versions,
      column: %i[package_version_id agency_id departure_id],
      primary_key: %i[id agency_id departure_id],
      name: "package_version_sales_states_version_fk"
    add_foreign_key :package_version_sales_states, :departures,
      column: %i[departure_id agency_id],
      primary_key: %i[id agency_id],
      name: "package_version_sales_states_departure_fk"

    add_foreign_key :service_offer_version_sales_states, :service_offer_versions,
      column: %i[service_offer_version_id agency_id departure_id],
      primary_key: %i[id agency_id departure_id],
      name: "so_version_sales_states_version_fk"
    add_foreign_key :service_offer_version_sales_states, :departures,
      column: %i[departure_id agency_id],
      primary_key: %i[id agency_id],
      name: "so_version_sales_states_departure_fk"

    add_foreign_key :package_publication_manifests, :package_versions,
      column: %i[package_version_id agency_id departure_id],
      primary_key: %i[id agency_id departure_id],
      name: "package_publication_manifests_version_fk"
    add_foreign_key :package_publication_manifests, :departures,
      column: %i[departure_id agency_id],
      primary_key: %i[id agency_id],
      name: "package_publication_manifests_departure_fk"
    add_foreign_key :package_publication_manifests, :agency_users,
      column: :actor_agency_user_id,
      name: "package_publication_manifests_actor_fk"

    add_foreign_key :service_offer_publication_manifests, :service_offer_versions,
      column: %i[service_offer_version_id agency_id departure_id],
      primary_key: %i[id agency_id departure_id],
      name: "so_publication_manifests_version_fk"
    add_foreign_key :service_offer_publication_manifests, :departures,
      column: %i[departure_id agency_id],
      primary_key: %i[id agency_id],
      name: "so_publication_manifests_departure_fk"
    add_foreign_key :service_offer_publication_manifests, :agency_users,
      column: :actor_agency_user_id,
      name: "so_publication_manifests_actor_fk"

    add_foreign_key :package_publication_results, :agency_command_idempotency_keys,
      column: %i[agency_command_idempotency_key_id agency_id],
      primary_key: %i[id agency_id],
      name: "package_publication_results_idempotency_fk"
    add_foreign_key :package_publication_results, :package_versions,
      column: %i[package_version_id agency_id departure_id],
      primary_key: %i[id agency_id departure_id],
      name: "package_publication_results_version_fk"
    add_foreign_key :package_publication_results, :departures,
      column: %i[departure_id agency_id],
      primary_key: %i[id agency_id],
      name: "package_publication_results_departure_fk"

    add_foreign_key :package_publication_result_service_versions, :package_publication_results,
      column: %i[package_publication_result_id agency_id],
      primary_key: %i[id agency_id],
      name: "pkg_pub_result_sovs_result_fk"
    add_foreign_key :package_publication_result_service_versions, :service_offer_versions,
      column: %i[service_offer_version_id agency_id],
      primary_key: %i[id agency_id],
      name: "pkg_pub_result_sovs_sov_fk"

    execute <<~SQL
      CREATE OR REPLACE FUNCTION reject_invalid_package_version_lifecycle() RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
          IF NOT (
            (OLD.status = 'draft' AND NEW.status IN ('abandoned', 'published'))
            OR (OLD.status = 'published' AND NEW.status IN ('superseded', 'retired'))
          ) THEN
            RAISE EXCEPTION 'package version status transition from % to % is not permitted',
              OLD.status, NEW.status;
          END IF;
        END IF;
        RETURN NEW;
      END;
      $$;
    SQL

    execute <<~SQL
      CREATE OR REPLACE FUNCTION reject_invalid_service_offer_version_lifecycle() RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
          IF NOT (
            (OLD.status = 'draft' AND NEW.status IN ('abandoned', 'published'))
            OR (OLD.status = 'published' AND NEW.status IN ('superseded', 'retired'))
          ) THEN
            RAISE EXCEPTION 'service offer version status transition from % to % is not permitted',
              OLD.status, NEW.status;
          END IF;
        END IF;
        RETURN NEW;
      END;
      $$;
    SQL

    execute <<~SQL
      CREATE OR REPLACE FUNCTION reject_publication_manifest_mutation() RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        RAISE EXCEPTION 'publication manifests are immutable';
      END;
      $$;
    SQL

    execute <<~SQL
      CREATE TRIGGER package_publication_manifests_reject_mutation
        BEFORE UPDATE OR DELETE ON public.package_publication_manifests
        FOR EACH ROW EXECUTE FUNCTION public.reject_publication_manifest_mutation();
      CREATE TRIGGER service_offer_publication_manifests_reject_mutation
        BEFORE UPDATE OR DELETE ON public.service_offer_publication_manifests
        FOR EACH ROW EXECUTE FUNCTION public.reject_publication_manifest_mutation();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS package_publication_manifests_reject_mutation ON public.package_publication_manifests;
      DROP TRIGGER IF EXISTS service_offer_publication_manifests_reject_mutation ON public.service_offer_publication_manifests;
      DROP FUNCTION IF EXISTS reject_publication_manifest_mutation();
    SQL

    drop_table :package_publication_result_service_versions
    drop_table :package_publication_results
    drop_table :service_offer_publication_manifests
    drop_table :package_publication_manifests
    drop_table :service_offer_version_sales_states
    drop_table :package_version_sales_states

    remove_column :service_offer_versions, :retired_at
    remove_column :package_versions, :retired_at
    remove_column :service_offer_versions, :published_at
    remove_column :package_versions, :published_at
    remove_column :service_offer_versions, :copied_from_version_id
    remove_column :package_versions, :copied_from_version_id
    remove_column :service_offers, :current_published_version_id
    remove_column :packages, :current_published_version_id
  end
end
