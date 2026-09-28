# frozen_string_literal: true

class AddCruiseAgreementConfirmationAndTerms < ActiveRecord::Migration[8.1]
  TERM_TYPES = %w[allocated_cabin_deposit card_restrictions cancellation_step].freeze

  def up
    create_confirmations!
    create_terms!
    create_capacity_deposit_requirements!
    replace_supplier_code_uniqueness!
    freeze_draft_definitions!
  end

  def down
    execute "DROP TRIGGER IF EXISTS cruise_agreement_confirmations_reject_non_draft ON public.supplier_arrangement_cruise_agreement_confirmations"
    execute "DROP TRIGGER IF EXISTS cruise_term_definitions_reject_non_draft ON public.supplier_arrangement_cruise_term_definitions"
    execute "DROP TRIGGER IF EXISTS cruise_agreement_confirmations_reject_owner_change ON public.supplier_arrangement_cruise_agreement_confirmations"
    execute "DROP TRIGGER IF EXISTS cruise_term_definitions_reject_owner_change ON public.supplier_arrangement_cruise_term_definitions"
    execute "DROP FUNCTION IF EXISTS reject_cruise_agreement_confirmation_owner_change()"
    execute "DROP FUNCTION IF EXISTS reject_cruise_term_definition_owner_change()"
    drop_table :supplier_arrangement_cruise_capacity_deposit_requirements, if_exists: true
    drop_table :supplier_arrangement_cruise_term_definitions, if_exists: true
    drop_table :supplier_arrangement_cruise_agreement_confirmations, if_exists: true
    remove_index :supplier_resource_definitions,
      name: "supplier_resource_defs_code_and_name_unique",
      if_exists: true
    add_index :supplier_resource_definitions,
      "supplier_arrangement_version_id, arrangement_item_id, lower(btrim((supplier_code)::text))",
      unique: true,
      where: "supplier_code IS NOT NULL",
      name: "supplier_resource_defs_supplier_code_unique"
  end

  private

  def create_confirmations!
    create_table :supplier_arrangement_cruise_agreement_confirmations,
      id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.uuid :supplier_arrangement_version_id, null: false
      table.date :group_creation_date
      table.string :group_reference, limit: 80
      table.date :contract_date
      table.string :note, limit: 2000
      table.string :deposit_treatment, limit: 2000
      table.string :status, null: false
      table.boolean :current, null: false, default: true
      table.timestamptz :confirmed_at
      table.uuid :confirmed_by_id
      table.uuid :corrects_id
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :supplier_arrangement_cruise_agreement_confirmations,
      [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_cruise_agreement_confirmations_on_lineage"
    add_index :supplier_arrangement_cruise_agreement_confirmations,
      :supplier_arrangement_version_id,
      unique: true,
      where: "current",
      name: "index_cruise_agreement_confirmations_one_current"
    add_foreign_key :supplier_arrangement_cruise_agreement_confirmations, :supplier_arrangement_versions,
      column: [ :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "cruise_agreement_confirmations_version_fk"
    add_foreign_key :supplier_arrangement_cruise_agreement_confirmations, :agency_users,
      column: [ :confirmed_by_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "cruise_agreement_confirmations_actor_fk"
    add_foreign_key :supplier_arrangement_cruise_agreement_confirmations,
      :supplier_arrangement_cruise_agreement_confirmations,
      column: [ :corrects_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "cruise_agreement_confirmations_corrects_fk"

    add_check_constraint :supplier_arrangement_cruise_agreement_confirmations,
      "status IN ('provisional', 'confirmed')",
      name: "cruise_agreement_confirmations_status"
    add_check_constraint :supplier_arrangement_cruise_agreement_confirmations,
      <<~SQL.squish,
        (
          status = 'provisional'
          AND confirmed_at IS NULL
          AND confirmed_by_id IS NULL
        ) OR (
          status = 'confirmed'
          AND confirmed_at IS NOT NULL
          AND confirmed_by_id IS NOT NULL
          AND group_reference IS NOT NULL
          AND contract_date IS NOT NULL
        )
      SQL
      name: "cruise_agreement_confirmations_status_shape"
    add_check_constraint :supplier_arrangement_cruise_agreement_confirmations,
      "group_reference IS NULL OR (btrim(group_reference) <> '' AND char_length(group_reference) <= 80)",
      name: "cruise_agreement_confirmations_group_reference"
    add_check_constraint :supplier_arrangement_cruise_agreement_confirmations,
      "note IS NULL OR (btrim(note) <> '' AND char_length(note) <= 2000)",
      name: "cruise_agreement_confirmations_note"
    add_check_constraint :supplier_arrangement_cruise_agreement_confirmations,
      "deposit_treatment IS NULL OR (btrim(deposit_treatment) <> '' AND char_length(deposit_treatment) <= 2000)",
      name: "cruise_agreement_confirmations_deposit_treatment"
    add_check_constraint :supplier_arrangement_cruise_agreement_confirmations,
      "lock_version >= 0",
      name: "cruise_agreement_confirmations_lock_version"
  end

  def create_terms!
    create_table :supplier_arrangement_cruise_term_definitions,
      id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.uuid :supplier_arrangement_version_id, null: false
      table.string :term_type, null: false
      table.integer :position, null: false
      table.string :body, limit: 4000, null: false
      table.bigint :amount_minor_units
      table.bigint :credit_minor_units
      table.string :currency, limit: 3
      table.integer :days_before_departure
      table.uuid :copied_from_id
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :supplier_arrangement_cruise_term_definitions,
      [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_cruise_term_definitions_on_lineage"
    add_index :supplier_arrangement_cruise_term_definitions,
      [ :supplier_arrangement_version_id, :term_type ],
      unique: true,
      where: "term_type IN ('allocated_cabin_deposit', 'card_restrictions')",
      name: "index_cruise_term_definitions_one_readable_term"
    add_index :supplier_arrangement_cruise_term_definitions,
      [ :supplier_arrangement_version_id, :position ],
      unique: true,
      where: "term_type = 'cancellation_step'",
      name: "index_cruise_term_definitions_cancellation_position"
    add_foreign_key :supplier_arrangement_cruise_term_definitions, :supplier_arrangement_versions,
      column: [ :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "cruise_term_definitions_version_fk"
    add_foreign_key :supplier_arrangement_cruise_term_definitions, :supplier_arrangement_cruise_term_definitions,
      column: [ :copied_from_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "cruise_term_definitions_copied_from_fk"
    add_check_constraint :supplier_arrangement_cruise_term_definitions,
      "term_type IN (#{TERM_TYPES.map { |type| "'#{type}'" }.join(', ')})",
      name: "cruise_term_definitions_term_type"
    add_check_constraint :supplier_arrangement_cruise_term_definitions,
      "btrim(body) <> '' AND char_length(body) <= 4000",
      name: "cruise_term_definitions_body"
    add_check_constraint :supplier_arrangement_cruise_term_definitions,
      "position > 0",
      name: "cruise_term_definitions_position"
    add_check_constraint :supplier_arrangement_cruise_term_definitions,
      <<~SQL.squish,
        (
          term_type = 'allocated_cabin_deposit'
          AND position = 1
          AND amount_minor_units > 0
          AND credit_minor_units >= 0
          AND currency ~ '^[A-Z]{3}$'
          AND days_before_departure IS NULL
        ) OR (
          term_type = 'card_restrictions'
          AND position = 1
          AND amount_minor_units IS NULL
          AND credit_minor_units IS NULL
          AND currency IS NULL
          AND days_before_departure IS NULL
        ) OR (
          term_type = 'cancellation_step'
          AND days_before_departure >= 0
          AND amount_minor_units IS NULL
          AND credit_minor_units IS NULL
          AND currency IS NULL
        )
      SQL
      name: "cruise_term_definitions_shape"
    add_check_constraint :supplier_arrangement_cruise_term_definitions,
      "lock_version >= 0",
      name: "cruise_term_definitions_lock_version"
  end

  def create_capacity_deposit_requirements!
    create_table :supplier_arrangement_cruise_capacity_deposit_requirements,
      id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.uuid :supplier_arrangement_version_id, null: false
      table.uuid :capacity_pool_id, null: false
      table.uuid :capacity_event_id, null: false
      table.integer :quantity, null: false
      table.bigint :rate_minor_units, null: false
      table.bigint :amount_minor_units, null: false
      table.string :currency, limit: 3, null: false
      table.timestamps null: false
    end

    add_index :supplier_arrangement_cruise_capacity_deposit_requirements,
      :capacity_event_id, unique: true,
      name: "index_cruise_capacity_deposit_requirements_on_event"
    add_foreign_key :supplier_arrangement_cruise_capacity_deposit_requirements, :supplier_arrangement_versions,
      column: [ :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "cruise_capacity_deposit_requirements_version_fk"
    add_foreign_key :supplier_arrangement_cruise_capacity_deposit_requirements, :capacity_events,
      column: [ :capacity_event_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "cruise_capacity_deposit_requirements_event_fk"
    add_foreign_key :supplier_arrangement_cruise_capacity_deposit_requirements, :capacity_pools,
      column: [ :capacity_pool_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "cruise_capacity_deposit_requirements_pool_fk"
    add_check_constraint :supplier_arrangement_cruise_capacity_deposit_requirements,
      "quantity > 0 AND rate_minor_units >= 0 AND amount_minor_units = quantity * rate_minor_units",
      name: "cruise_capacity_deposit_requirements_amount"
    add_check_constraint :supplier_arrangement_cruise_capacity_deposit_requirements,
      "currency ~ '^[A-Z]{3}$'",
      name: "cruise_capacity_deposit_requirements_currency"
  end

  def replace_supplier_code_uniqueness!
    remove_index :supplier_resource_definitions, name: "supplier_resource_defs_supplier_code_unique"
    add_index :supplier_resource_definitions,
      "supplier_arrangement_version_id, arrangement_item_id, lower(btrim((supplier_code)::text)), lower(btrim((name)::text))",
      unique: true,
      where: "supplier_code IS NOT NULL",
      name: "supplier_resource_defs_code_and_name_unique"
  end

  def freeze_draft_definitions!
    execute <<~SQL
      CREATE TRIGGER cruise_agreement_confirmations_reject_non_draft
        BEFORE INSERT OR UPDATE OR DELETE ON public.supplier_arrangement_cruise_agreement_confirmations
        FOR EACH ROW EXECUTE FUNCTION reject_non_draft_arrangement_version_definition_mutation();

      CREATE TRIGGER cruise_term_definitions_reject_non_draft
        BEFORE INSERT OR UPDATE OR DELETE ON public.supplier_arrangement_cruise_term_definitions
        FOR EACH ROW EXECUTE FUNCTION reject_non_draft_arrangement_version_definition_mutation();

      CREATE FUNCTION reject_cruise_agreement_confirmation_owner_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id
          OR NEW.supplier_arrangement_version_id IS DISTINCT FROM OLD.supplier_arrangement_version_id
          OR NEW.corrects_id IS DISTINCT FROM OLD.corrects_id
        THEN
          RAISE EXCEPTION 'cruise agreement confirmation owner is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER cruise_agreement_confirmations_reject_owner_change
        BEFORE UPDATE ON public.supplier_arrangement_cruise_agreement_confirmations
        FOR EACH ROW EXECUTE FUNCTION reject_cruise_agreement_confirmation_owner_change();

      CREATE FUNCTION reject_cruise_term_definition_owner_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id
          OR NEW.supplier_arrangement_version_id IS DISTINCT FROM OLD.supplier_arrangement_version_id
          OR NEW.term_type IS DISTINCT FROM OLD.term_type
          OR NEW.copied_from_id IS DISTINCT FROM OLD.copied_from_id
        THEN
          RAISE EXCEPTION 'cruise term definition owner is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER cruise_term_definitions_reject_owner_change
        BEFORE UPDATE ON public.supplier_arrangement_cruise_term_definitions
        FOR EACH ROW EXECUTE FUNCTION reject_cruise_term_definition_owner_change();
    SQL
  end
end
