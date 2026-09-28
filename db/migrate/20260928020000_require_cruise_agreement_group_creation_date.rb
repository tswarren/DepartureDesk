# frozen_string_literal: true

class RequireCruiseAgreementGroupCreationDate < ActiveRecord::Migration[8.1]
  STATUS_SHAPE = <<~SQL.squish
    (
      status = 'provisional'
      AND group_creation_date IS NOT NULL
      AND confirmed_at IS NULL
      AND confirmed_by_id IS NULL
    ) OR (
      status = 'confirmed'
      AND group_creation_date IS NOT NULL
      AND confirmed_at IS NOT NULL
      AND confirmed_by_id IS NOT NULL
      AND group_reference IS NOT NULL
      AND contract_date IS NOT NULL
    )
  SQL

  PREVIOUS_STATUS_SHAPE = <<~SQL.squish
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

  def up
    remove_check_constraint :supplier_arrangement_cruise_agreement_confirmations,
      name: "cruise_agreement_confirmations_status_shape"
    add_check_constraint :supplier_arrangement_cruise_agreement_confirmations,
      STATUS_SHAPE,
      name: "cruise_agreement_confirmations_status_shape"
  end

  def down
    remove_check_constraint :supplier_arrangement_cruise_agreement_confirmations,
      name: "cruise_agreement_confirmations_status_shape"
    add_check_constraint :supplier_arrangement_cruise_agreement_confirmations,
      PREVIOUS_STATUS_SHAPE,
      name: "cruise_agreement_confirmations_status_shape"
  end
end
