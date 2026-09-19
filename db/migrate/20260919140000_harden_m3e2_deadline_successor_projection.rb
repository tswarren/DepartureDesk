# frozen_string_literal: true

class HardenM3e2DeadlineSuccessorProjection < ActiveRecord::Migration[8.1]
  def up
    add_line_copied_from!
    retarget_disposition_replacement_fk!
    expand_projection_status!
  end

  def down
    revert_projection_status!
    revert_disposition_replacement_fk!
    remove_line_copied_from!
  end

  private

  def add_line_copied_from!
    add_column :supplier_deadline_commitment_definition_lines, :copied_from_id, :uuid
    add_index :supplier_deadline_commitment_definition_lines,
      [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_deadline_commitment_lines_on_lineage_owner"
    add_foreign_key :supplier_deadline_commitment_definition_lines,
      :supplier_deadline_commitment_definition_lines,
      column: [ :copied_from_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "deadline_commitment_lines_copied_from_fk"

    execute <<~SQL
      CREATE OR REPLACE FUNCTION reject_deadline_commitment_line_owner_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id
          OR NEW.supplier_arrangement_version_id IS DISTINCT FROM OLD.supplier_arrangement_version_id
          OR NEW.supplier_deadline_definition_id IS DISTINCT FROM OLD.supplier_deadline_definition_id
          OR NEW.copied_from_id IS DISTINCT FROM OLD.copied_from_id
        THEN
          RAISE EXCEPTION 'supplier deadline commitment definition line owner is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;

      DROP TRIGGER IF EXISTS supplier_deadline_commitment_definition_lines_reject_owner_change
        ON public.supplier_deadline_commitment_definition_lines;
      CREATE TRIGGER supplier_deadline_commitment_definition_lines_reject_owner_change
        BEFORE UPDATE ON public.supplier_deadline_commitment_definition_lines
        FOR EACH ROW EXECUTE FUNCTION reject_deadline_commitment_line_owner_change();
    SQL
  end

  def remove_line_copied_from!
    execute <<~SQL
      DROP TRIGGER IF EXISTS supplier_deadline_commitment_definition_lines_reject_owner_change
        ON public.supplier_deadline_commitment_definition_lines;
      DROP FUNCTION IF EXISTS reject_deadline_commitment_line_owner_change();
    SQL
    remove_foreign_key :supplier_deadline_commitment_definition_lines,
      name: "deadline_commitment_lines_copied_from_fk"
    remove_index :supplier_deadline_commitment_definition_lines,
      name: "index_deadline_commitment_lines_on_lineage_owner"
    remove_column :supplier_deadline_commitment_definition_lines, :copied_from_id
  end

  def retarget_disposition_replacement_fk!
    remove_foreign_key :supplier_commitment_dispositions, name: "commitment_dispositions_replacement_fk"
    add_index :supplier_commitments,
      [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_supplier_commitments_on_lineage_owner"
    add_foreign_key :supplier_commitment_dispositions, :supplier_commitments,
      column: [
        :replacement_supplier_commitment_id, :supplier_arrangement_id, :departure_id, :agency_id
      ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "commitment_dispositions_replacement_fk"
  end

  def revert_disposition_replacement_fk!
    remove_foreign_key :supplier_commitment_dispositions, name: "commitment_dispositions_replacement_fk"
    remove_index :supplier_commitments, name: "index_supplier_commitments_on_lineage_owner"
    add_foreign_key :supplier_commitment_dispositions, :supplier_commitments,
      column: [
        :replacement_supplier_commitment_id, :supplier_arrangement_version_id,
        :supplier_arrangement_id, :departure_id, :agency_id
      ],
      primary_key: [
        :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id
      ],
      name: "commitment_dispositions_replacement_fk"
  end

  def expand_projection_status!
    remove_check_constraint :supplier_deadline_projections, name: "deadline_projections_status"
    add_check_constraint :supplier_deadline_projections,
      "status IN ('upcoming', 'warning', 'due', 'overdue', 'superseded')",
      name: "deadline_projections_status"
  end

  def revert_projection_status!
    execute <<~SQL
      UPDATE supplier_deadline_projections
      SET status = 'upcoming', next_transition_at = NULL
      WHERE status = 'superseded'
    SQL
    remove_check_constraint :supplier_deadline_projections, name: "deadline_projections_status"
    add_check_constraint :supplier_deadline_projections,
      "status IN ('upcoming', 'warning', 'due', 'overdue')",
      name: "deadline_projections_status"
  end
end
