# frozen_string_literal: true

# Slice 1 step 2 (DEP-16, DEP-19, DEP-20): each operating decision records
# its value, who made it, when, and an optional note. The history is
# append-only; departures.operating_decision holds the latest value.
class CreateDepartureDecisions < ActiveRecord::Migration[8.1]
  def up
    create_table :departure_decisions, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :departure_id, null: false
      table.string :decision, null: false
      table.text :note
      table.uuid :decided_by_id, null: false
      table.datetime :decided_at, null: false
      table.datetime :created_at, null: false

      table.index %i[departure_id decided_at], name: "index_departure_decisions_on_departure_and_decided_at"
      table.check_constraint "decision IN ('proceed', 'postpone', 'cancel')", name: "departure_decisions_decision"
      table.check_constraint "note IS NULL OR (btrim(note) <> '' AND char_length(note) <= 2000)", name: "departure_decisions_note"
      table.check_constraint "decision = 'proceed' OR note IS NOT NULL", name: "departure_decisions_note_required"
    end
    add_foreign_key :departure_decisions, :agencies, column: :agency_id, name: "fk_departure_decisions_agency"
    execute <<~SQL
      ALTER TABLE departure_decisions
        ADD CONSTRAINT fk_departure_decisions_departure_same_agency
        FOREIGN KEY (departure_id, agency_id) REFERENCES departures (id, agency_id),
        ADD CONSTRAINT fk_departure_decisions_decided_by_same_agency
        FOREIGN KEY (decided_by_id, agency_id) REFERENCES agency_users (id, agency_id);

      CREATE FUNCTION public.reject_departure_decision_mutation() RETURNS trigger
          LANGUAGE plpgsql
          AS $$
      BEGIN
        RAISE EXCEPTION 'departure decisions are append-only';
      END;
      $$;

      CREATE TRIGGER departure_decisions_reject_mutation BEFORE DELETE OR UPDATE ON public.departure_decisions
        FOR EACH ROW EXECUTE FUNCTION public.reject_departure_decision_mutation();
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
