# frozen_string_literal: true

# Slice 1 step 2 (D-91): a Departure receives its reference when it is
# created, so every Departure, a Draft included, has one. Drafts without a
# reference are numbered here from their agency's sequence, oldest first.
# first_activated_at existed only to pair with the reference and is dropped.
class IssueDepartureReferenceAtCreation < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :departures, name: "departures_non_draft_has_reference"
    remove_check_constraint :departures, name: "departures_reference_activation_pair"

    execute <<~SQL
      WITH numbered AS (
        SELECT departures.id,
          sequences.next_value - 1 + row_number() OVER (PARTITION BY departures.agency_id ORDER BY departures.created_at, departures.id) AS number
        FROM departures
        JOIN reference_sequences sequences
          ON sequences.agency_id = departures.agency_id AND sequences.namespace = 'departure'
        WHERE departures.departure_reference IS NULL
      )
      UPDATE departures
      SET departure_reference = 'DEP-' || lpad(numbered.number::text, 4, '0')
      FROM numbered
      WHERE departures.id = numbered.id;

      UPDATE reference_sequences
      SET next_value = next_value + counts.issued, updated_at = now()
      FROM (
        SELECT agency_id, count(*) AS issued
        FROM departures
        WHERE first_activated_at IS NULL
        GROUP BY agency_id
      ) counts
      WHERE reference_sequences.agency_id = counts.agency_id
        AND reference_sequences.namespace = 'departure';
    SQL

    execute <<~SQL
      CREATE OR REPLACE FUNCTION public.reject_departure_identity_change() RETURNS trigger
          LANGUAGE plpgsql
          AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id THEN
          RAISE EXCEPTION 'departure identity is immutable';
        END IF;
        IF NEW.departure_reference IS DISTINCT FROM OLD.departure_reference THEN
          RAISE EXCEPTION 'departure identity is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;
    SQL

    remove_column :departures, :first_activated_at
    change_column_null :departures, :departure_reference, false
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
