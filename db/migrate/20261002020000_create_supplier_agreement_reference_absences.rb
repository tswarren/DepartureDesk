# frozen_string_literal: true

class CreateSupplierAgreementReferenceAbsences < ActiveRecord::Migration[8.1]
  KINDS = %w[
    deposit_derivation attrition deposit_refund
    destination_fee additional_nights early_departure cancellation
  ].freeze
  ITEM_KINDS = %w[deposit_derivation attrition deposit_refund].freeze

  def up
    create_table :supplier_agreement_reference_absences, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.uuid :supplier_arrangement_version_id, null: false
      table.uuid :arrangement_item_id
      table.string :kind, null: false
      table.uuid :recorded_by_id, null: false
      table.timestamptz :recorded_at, null: false
      table.uuid :copied_from_id
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :supplier_agreement_reference_absences, [ :id, :agency_id ],
      unique: true, name: "index_agreement_reference_absences_on_id_agency"
    add_index :supplier_agreement_reference_absences,
      [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_agreement_reference_absences_on_lineage_owner"
    add_index :supplier_agreement_reference_absences,
      [ :supplier_arrangement_version_id, :arrangement_item_id, :kind ],
      unique: true, where: "arrangement_item_id IS NOT NULL",
      name: "index_agreement_reference_absences_on_version_item_kind"
    add_index :supplier_agreement_reference_absences,
      [ :supplier_arrangement_version_id, :kind ],
      unique: true, where: "arrangement_item_id IS NULL",
      name: "index_agreement_reference_absences_on_version_kind_without_item"

    add_foreign_key :supplier_agreement_reference_absences, :agencies
    add_foreign_key :supplier_agreement_reference_absences, :supplier_arrangement_versions,
      column: [ :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "agreement_reference_absences_version_fk"
    add_foreign_key :supplier_agreement_reference_absences, :arrangement_items,
      column: [ :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "agreement_reference_absences_item_fk"
    add_foreign_key :supplier_agreement_reference_absences, :supplier_agreement_reference_absences,
      column: [ :copied_from_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "agreement_reference_absences_copied_from_fk"
    add_foreign_key :supplier_agreement_reference_absences, :agency_users,
      column: [ :recorded_by_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "agreement_reference_absences_recorder_fk"

    add_check_constraint :supplier_agreement_reference_absences,
      "kind IN (#{KINDS.map { |kind| "'#{kind}'" }.join(", ")}) AND " \
      "(kind NOT IN (#{ITEM_KINDS.map { |kind| "'#{kind}'" }.join(", ")}) OR arrangement_item_id IS NOT NULL)",
      name: "agreement_reference_absences_kind"
    add_check_constraint :supplier_agreement_reference_absences,
      "lock_version >= 0",
      name: "agreement_reference_absences_lock_version"

    execute <<~SQL
      CREATE OR REPLACE FUNCTION public.reject_mixed_agreement_reference_scope() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        PERFORM id
          FROM supplier_arrangement_versions
         WHERE id = NEW.supplier_arrangement_version_id
           FOR UPDATE;

        IF TG_OP = 'UPDATE'
           AND OLD.supplier_arrangement_version_id IS NOT DISTINCT FROM NEW.supplier_arrangement_version_id
           AND OLD.kind IS NOT DISTINCT FROM NEW.kind
           AND OLD.arrangement_item_id IS NOT DISTINCT FROM NEW.arrangement_item_id
        THEN
          RETURN NEW;
        END IF;

        IF EXISTS (
          SELECT 1
            FROM supplier_agreement_references existing
           WHERE existing.supplier_arrangement_version_id = NEW.supplier_arrangement_version_id
             AND existing.kind = NEW.kind
             AND (TG_TABLE_NAME <> 'supplier_agreement_references' OR existing.id IS DISTINCT FROM NEW.id)
             AND (existing.arrangement_item_id IS NULL) IS DISTINCT FROM (NEW.arrangement_item_id IS NULL)
        ) OR EXISTS (
          SELECT 1
            FROM supplier_agreement_reference_absences existing
           WHERE existing.supplier_arrangement_version_id = NEW.supplier_arrangement_version_id
             AND existing.kind = NEW.kind
             AND (TG_TABLE_NAME <> 'supplier_agreement_reference_absences' OR existing.id IS DISTINCT FROM NEW.id)
             AND (existing.arrangement_item_id IS NULL) IS DISTINCT FROM (NEW.arrangement_item_id IS NULL)
        ) THEN
          RAISE EXCEPTION 'an agreement reference kind cannot use both Item scope and agreement-wide scope';
        END IF;

        IF TG_TABLE_NAME = 'supplier_agreement_references' AND EXISTS (
          SELECT 1
            FROM supplier_agreement_reference_absences existing
           WHERE existing.supplier_arrangement_version_id = NEW.supplier_arrangement_version_id
             AND existing.kind = NEW.kind
             AND existing.arrangement_item_id IS NOT DISTINCT FROM NEW.arrangement_item_id
        ) THEN
          RAISE EXCEPTION 'an agreement reference kind cannot have both wording and reviewed none';
        END IF;

        IF TG_TABLE_NAME = 'supplier_agreement_reference_absences' AND EXISTS (
          SELECT 1
            FROM supplier_agreement_references existing
           WHERE existing.supplier_arrangement_version_id = NEW.supplier_arrangement_version_id
             AND existing.kind = NEW.kind
             AND existing.arrangement_item_id IS NOT DISTINCT FROM NEW.arrangement_item_id
        ) THEN
          RAISE EXCEPTION 'an agreement reference kind cannot have both wording and reviewed none';
        END IF;

        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER supplier_agreement_reference_absences_guard_mixed_scope
        BEFORE INSERT OR UPDATE ON public.supplier_agreement_reference_absences
        FOR EACH ROW EXECUTE FUNCTION reject_mixed_agreement_reference_scope();

      CREATE TRIGGER supplier_agreement_reference_absences_reject_confirmed
        BEFORE INSERT OR UPDATE OR DELETE ON public.supplier_agreement_reference_absences
        FOR EACH ROW EXECUTE FUNCTION reject_confirmed_agreement_reference_mutation();

      CREATE TRIGGER supplier_agreement_reference_absences_reject_non_draft
        BEFORE INSERT OR UPDATE OR DELETE ON public.supplier_agreement_reference_absences
        FOR EACH ROW EXECUTE FUNCTION reject_non_draft_arrangement_version_definition_mutation();

      CREATE TRIGGER supplier_agreement_reference_absences_reject_owner_change
        BEFORE UPDATE ON public.supplier_agreement_reference_absences
        FOR EACH ROW EXECUTE FUNCTION reject_supplier_term_owner_change(
          'agency_id', 'departure_id', 'supplier_arrangement_id',
          'supplier_arrangement_version_id', 'arrangement_item_id', 'kind', 'copied_from_id'
        );
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
