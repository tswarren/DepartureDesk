# frozen_string_literal: true

class HardenM3e1aCommitmentDispositionInvariants < ActiveRecord::Migration[8.1]
  def up
    expand_confirmation_evidence_kinds!
    add_membership_owner_index!
    replace_disposition_coverage_fk_with_membership_fk!
    create_disposition_invariant_functions!
    create_disposition_invariant_triggers!
  end

  def down
    execute "DROP TRIGGER IF EXISTS supplier_commitment_dispositions_enforce_current ON supplier_commitment_dispositions"
    execute "DROP TRIGGER IF EXISTS supplier_commitment_dispositions_enforce_coverage_purpose ON supplier_commitment_dispositions"
    execute "DROP TRIGGER IF EXISTS supplier_commitment_evidence_members_reject_after_disposition ON supplier_commitment_evidence_coverage_members"
    execute "DROP FUNCTION IF EXISTS reject_second_current_commitment_disposition()"
    execute "DROP FUNCTION IF EXISTS enforce_commitment_disposition_coverage_purpose()"
    execute "DROP FUNCTION IF EXISTS reject_evidence_member_after_disposition()"

    remove_foreign_key :supplier_commitment_dispositions, name: "commitment_dispositions_membership_fk"
    add_foreign_key :supplier_commitment_dispositions, :supplier_commitment_evidence_coverages,
      column: [
        :supplier_commitment_evidence_coverage_id, :supplier_arrangement_version_id,
        :supplier_arrangement_id, :departure_id, :agency_id
      ],
      primary_key: [
        :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id
      ],
      name: "commitment_dispositions_coverage_fk"
    remove_index :supplier_commitment_evidence_coverage_members,
      name: "index_commitment_evidence_members_on_coverage_commitment_owner"

    revert_confirmation_evidence_kinds!
  end

  private

  def expand_confirmation_evidence_kinds!
    remove_check_constraint :supplier_confirmations, name: "supplier_confirmations_evidence_kind"
    add_check_constraint :supplier_confirmations,
      "evidence_kind IN (" \
        "'contract', 'supplier_confirmation', 'supplier_message', 'supplier_portal', " \
        "'verbal_confirmation', 'supplier_release', 'contract_release', 'other'" \
      ")",
      name: "supplier_confirmations_evidence_kind"
  end

  def revert_confirmation_evidence_kinds!
    remove_check_constraint :supplier_confirmations, name: "supplier_confirmations_evidence_kind"
    add_check_constraint :supplier_confirmations,
      "evidence_kind IN (" \
        "'contract', 'supplier_confirmation', 'supplier_message', 'supplier_portal', " \
        "'verbal_confirmation', 'other'" \
      ")",
      name: "supplier_confirmations_evidence_kind"
  end

  def add_membership_owner_index!
    add_index :supplier_commitment_evidence_coverage_members,
      [
        :supplier_commitment_evidence_coverage_id, :supplier_commitment_id,
        :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id
      ],
      unique: true,
      name: "index_commitment_evidence_members_on_coverage_commitment_owner"
  end

  def replace_disposition_coverage_fk_with_membership_fk!
    remove_foreign_key :supplier_commitment_dispositions, name: "commitment_dispositions_coverage_fk"
    add_foreign_key :supplier_commitment_dispositions, :supplier_commitment_evidence_coverage_members,
      column: [
        :supplier_commitment_evidence_coverage_id, :supplier_commitment_id,
        :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id
      ],
      primary_key: [
        :supplier_commitment_evidence_coverage_id, :supplier_commitment_id,
        :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id
      ],
      name: "commitment_dispositions_membership_fk"
  end

  def create_disposition_invariant_functions!
    execute <<~SQL.squish
      CREATE OR REPLACE FUNCTION reject_second_current_commitment_disposition() RETURNS trigger AS $$
      BEGIN
        IF EXISTS (
          SELECT 1
          FROM supplier_commitment_dispositions d
          LEFT JOIN supplier_commitment_reopenings r
            ON r.supplier_commitment_disposition_id = d.id
          WHERE d.supplier_commitment_id = NEW.supplier_commitment_id
            AND r.id IS NULL
        ) THEN
          RAISE EXCEPTION 'commitment already has a current disposition'
            USING ERRCODE = 'check_violation';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    execute <<~SQL.squish
      CREATE OR REPLACE FUNCTION enforce_commitment_disposition_coverage_purpose() RETURNS trigger AS $$
      DECLARE
        coverage_purpose text;
      BEGIN
        IF NEW.supplier_commitment_evidence_coverage_id IS NULL THEN
          RETURN NEW;
        END IF;
        SELECT purpose INTO coverage_purpose
        FROM supplier_commitment_evidence_coverages
        WHERE id = NEW.supplier_commitment_evidence_coverage_id;
        IF coverage_purpose IS DISTINCT FROM NEW.outcome THEN
          RAISE EXCEPTION 'disposition outcome must match evidence coverage purpose'
            USING ERRCODE = 'check_violation';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    execute <<~SQL.squish
      CREATE OR REPLACE FUNCTION reject_evidence_member_after_disposition() RETURNS trigger AS $$
      BEGIN
        IF EXISTS (
          SELECT 1
          FROM supplier_commitment_dispositions
          WHERE supplier_commitment_evidence_coverage_id = NEW.supplier_commitment_evidence_coverage_id
        ) THEN
          RAISE EXCEPTION 'evidence coverage membership is sealed after disposition'
            USING ERRCODE = 'check_violation';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL
  end

  def create_disposition_invariant_triggers!
    execute <<~SQL.squish
      CREATE TRIGGER supplier_commitment_dispositions_enforce_current
      BEFORE INSERT ON supplier_commitment_dispositions
      FOR EACH ROW EXECUTE FUNCTION reject_second_current_commitment_disposition();
    SQL
    execute <<~SQL.squish
      CREATE TRIGGER supplier_commitment_dispositions_enforce_coverage_purpose
      BEFORE INSERT ON supplier_commitment_dispositions
      FOR EACH ROW EXECUTE FUNCTION enforce_commitment_disposition_coverage_purpose();
    SQL
    execute <<~SQL.squish
      CREATE TRIGGER supplier_commitment_evidence_members_reject_after_disposition
      BEFORE INSERT ON supplier_commitment_evidence_coverage_members
      FOR EACH ROW EXECUTE FUNCTION reject_evidence_member_after_disposition();
    SQL
  end
end
