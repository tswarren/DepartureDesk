# frozen_string_literal: true

class CreateM4d0OutlineFoundation < ActiveRecord::Migration[8.1]
  def up
    add_column :departures, :target_timing_text, :string
    add_column :service_offer_definitions, :client_timing_text, :string

    execute <<~SQL.squish
      ALTER TABLE departures
        ADD CONSTRAINT departures_target_timing_text
        CHECK (
          target_timing_text IS NULL
          OR (
            btrim(target_timing_text::text) <> ''
            AND char_length(target_timing_text::text) <= 160
          )
        )
    SQL

    execute <<~SQL.squish
      ALTER TABLE service_offer_definitions
        ADD CONSTRAINT service_offer_definitions_client_timing_text
        CHECK (
          client_timing_text IS NULL
          OR (
            btrim(client_timing_text::text) <> ''
            AND char_length(client_timing_text::text) <= 160
          )
        )
    SQL

    execute <<~SQL.squish
      ALTER TABLE service_offer_definitions
        DROP CONSTRAINT service_offer_definitions_fulfillment_basis
    SQL

    execute <<~SQL.squish
      ALTER TABLE service_offer_definitions
        ADD CONSTRAINT service_offer_definitions_fulfillment_basis
        CHECK (
          fulfillment_basis::text = ANY (
            ARRAY[
              'm3_backed'::character varying,
              'on_request'::character varying,
              'agency_fulfilled'::character varying,
              'externally_fulfilled'::character varying,
              'undecided'::character varying
            ]::text[]
          )
        )
    SQL
  end

  def down
    execute <<~SQL.squish
      ALTER TABLE service_offer_definitions
        DROP CONSTRAINT service_offer_definitions_fulfillment_basis
    SQL

    execute <<~SQL.squish
      ALTER TABLE service_offer_definitions
        ADD CONSTRAINT service_offer_definitions_fulfillment_basis
        CHECK (
          fulfillment_basis::text = ANY (
            ARRAY[
              'm3_backed'::character varying,
              'on_request'::character varying,
              'agency_fulfilled'::character varying,
              'externally_fulfilled'::character varying
            ]::text[]
          )
        )
    SQL

    execute <<~SQL.squish
      ALTER TABLE service_offer_definitions
        DROP CONSTRAINT service_offer_definitions_client_timing_text
    SQL

    execute <<~SQL.squish
      ALTER TABLE departures
        DROP CONSTRAINT departures_target_timing_text
    SQL

    remove_column :service_offer_definitions, :client_timing_text
    remove_column :departures, :target_timing_text
  end
end
