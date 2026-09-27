# frozen_string_literal: true

class AddCruisePortsAndCommercialBenefits < ActiveRecord::Migration[8.1]
  TERM_TYPES = %w[tour_conductor_credit group_amenity_program].freeze

  def up
    add_port_names!
    create_benefits!
    create_benefit_definitions!
    freeze_benefit_definitions!
  end

  def down
    execute "DROP TRIGGER IF EXISTS commercial_benefit_definitions_reject_non_draft ON public.supplier_arrangement_commercial_benefit_definitions"
    execute "DROP TRIGGER IF EXISTS commercial_benefit_definitions_reject_owner_change ON public.supplier_arrangement_commercial_benefit_definitions"
    execute "DROP FUNCTION IF EXISTS reject_commercial_benefit_definition_owner_change()"
    drop_table :supplier_arrangement_commercial_benefit_definitions, if_exists: true
    drop_table :supplier_arrangement_commercial_benefits, if_exists: true
    remove_column :service_occurrence_definitions, :return_port_name, if_exists: true
    remove_column :service_occurrence_definitions, :departure_port_name, if_exists: true
  end

  private

  def add_port_names!
    change_table :service_occurrence_definitions, bulk: true do |table|
      table.string :departure_port_name, limit: 160
      table.string :return_port_name, limit: 160
    end

    add_check_constraint :service_occurrence_definitions,
      "departure_port_name IS NULL OR (btrim(departure_port_name) <> '' AND char_length(departure_port_name) <= 160)",
      name: "service_occurrence_definitions_departure_port_name"
    add_check_constraint :service_occurrence_definitions,
      "return_port_name IS NULL OR (btrim(return_port_name) <> '' AND char_length(return_port_name) <= 160)",
      name: "service_occurrence_definitions_return_port_name"
  end

  def create_benefits!
    create_table :supplier_arrangement_commercial_benefits, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.timestamps null: false
    end

    add_index :supplier_arrangement_commercial_benefits, [ :id, :agency_id ],
      unique: true, name: "index_commercial_benefits_on_id_agency"
    add_index :supplier_arrangement_commercial_benefits,
      [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_commercial_benefits_on_full_owner"
    add_foreign_key :supplier_arrangement_commercial_benefits, :agencies
    add_foreign_key :supplier_arrangement_commercial_benefits, :supplier_arrangements,
      column: [ :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :departure_id, :agency_id ],
      name: "commercial_benefits_arrangement_fk"
  end

  def create_benefit_definitions!
    create_table :supplier_arrangement_commercial_benefit_definitions, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.uuid :supplier_arrangement_version_id, null: false
      table.uuid :supplier_arrangement_commercial_benefit_id, null: false
      table.string :term_type, null: false
      table.string :body, null: false, limit: 4_000
      table.string :source_citation, limit: 160
      table.uuid :copied_from_id
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :supplier_arrangement_commercial_benefit_definitions, [ :id, :agency_id ],
      unique: true, name: "index_commercial_benefit_defs_on_id_agency"
    add_index :supplier_arrangement_commercial_benefit_definitions,
      [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_commercial_benefit_defs_on_lineage_owner"
    add_index :supplier_arrangement_commercial_benefit_definitions,
      [ :supplier_arrangement_version_id, :term_type ],
      unique: true, name: "index_commercial_benefit_defs_on_version_and_type"
    add_foreign_key :supplier_arrangement_commercial_benefit_definitions, :agencies
    add_foreign_key :supplier_arrangement_commercial_benefit_definitions, :supplier_arrangement_versions,
      column: [ :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "commercial_benefit_defs_version_fk"
    add_foreign_key :supplier_arrangement_commercial_benefit_definitions, :supplier_arrangement_commercial_benefits,
      column: [ :supplier_arrangement_commercial_benefit_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "commercial_benefit_defs_benefit_fk"
    add_foreign_key :supplier_arrangement_commercial_benefit_definitions, :supplier_arrangement_commercial_benefit_definitions,
      column: [ :copied_from_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "commercial_benefit_defs_copied_from_fk"
    add_check_constraint :supplier_arrangement_commercial_benefit_definitions,
      "term_type IN (#{TERM_TYPES.map { |type| "'#{type}'" }.join(', ')})",
      name: "commercial_benefit_defs_term_type"
    add_check_constraint :supplier_arrangement_commercial_benefit_definitions,
      "btrim(body) <> '' AND char_length(body) <= 4000",
      name: "commercial_benefit_defs_body"
    add_check_constraint :supplier_arrangement_commercial_benefit_definitions,
      "source_citation IS NULL OR (btrim(source_citation) <> '' AND char_length(source_citation) <= 160)",
      name: "commercial_benefit_defs_source_citation"
    add_check_constraint :supplier_arrangement_commercial_benefit_definitions,
      "lock_version >= 0",
      name: "commercial_benefit_defs_lock_version"
  end

  def freeze_benefit_definitions!
    execute <<~SQL
      CREATE TRIGGER commercial_benefit_definitions_reject_non_draft
        BEFORE INSERT OR UPDATE OR DELETE ON public.supplier_arrangement_commercial_benefit_definitions
        FOR EACH ROW EXECUTE FUNCTION reject_non_draft_arrangement_version_definition_mutation();

      CREATE FUNCTION reject_commercial_benefit_definition_owner_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id
          OR NEW.supplier_arrangement_version_id IS DISTINCT FROM OLD.supplier_arrangement_version_id
          OR NEW.supplier_arrangement_commercial_benefit_id IS DISTINCT FROM OLD.supplier_arrangement_commercial_benefit_id
          OR NEW.term_type IS DISTINCT FROM OLD.term_type
          OR NEW.copied_from_id IS DISTINCT FROM OLD.copied_from_id
        THEN
          RAISE EXCEPTION 'commercial benefit definition owner is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER commercial_benefit_definitions_reject_owner_change
        BEFORE UPDATE ON public.supplier_arrangement_commercial_benefit_definitions
        FOR EACH ROW EXECUTE FUNCTION reject_commercial_benefit_definition_owner_change();
    SQL
  end
end
