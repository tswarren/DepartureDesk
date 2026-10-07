# frozen_string_literal: true

class CruiseActivationReview < ActiveRecord::Migration[8.1]
  def change
    change_column_null :supplier_confirmations, :evidence_on, true
    change_column_null :supplier_confirmations, :channel, true
    change_column_null :supplier_confirmations, :reference_note, true

    remove_check_constraint :supplier_confirmations, name: "supplier_confirmations_channel"
    add_check_constraint :supplier_confirmations,
      "channel IS NULL OR (btrim(channel) <> '' AND char_length(channel) <= 80)",
      name: "supplier_confirmations_channel"

    remove_check_constraint :supplier_confirmations, name: "supplier_confirmations_reference_note"
    add_check_constraint :supplier_confirmations,
      "reference_note IS NULL OR (btrim(reference_note) <> '' AND char_length(reference_note) <= 500)",
      name: "supplier_confirmations_reference_note"

    %i[capacity_pool_definitions capacity_events].each do |table_name|
      change_table table_name, bulk: true do |table|
        table.string :evidence_on_origin
        table.string :evidence_reference_origin
      end

      add_check_constraint table_name,
        <<~SQL.squish,
          (evidence_on_origin IS NULL OR evidence_on_origin IN ('supplied', 'agreement_contract_date'))
          AND (evidence_reference_origin IS NULL OR evidence_reference_origin IN ('supplier', 'activation_attestation'))
          AND (
            override = false
            OR (evidence_on_origin IS NULL AND evidence_reference_origin IS NULL)
          )
        SQL
        name: "#{table_name}_evidence_origins"
    end

    add_reference :capacity_pool_definitions, :opening_authority_confirmation,
      type: :uuid, foreign_key: { to_table: :supplier_confirmations }, null: true
  end
end
