# frozen_string_literal: true

# Slice 1 step 5 (BKG-13 to BKG-16, BKG-21, BKG-23): a Departure's package
# offering, its choices (each included or an add-on, with a scope and a
# pattern) and their options, each drawing on one inventory group, and the
# client prices set on each option.
class CreateOfferings < ActiveRecord::Migration[8.1]
  POSITIONS = [ "any", "single", *(1..9).map { |n| "guest_#{n}" } ].freeze

  def up
    create_table :offerings, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :departure_id, null: false
      table.string :name, null: false
      table.text :description
      table.string :currency, null: false
      table.integer :position, null: false, default: 0
      table.integer :lock_version, null: false, default: 0
      table.timestamps

      table.index %i[departure_id name], unique: true, name: "index_offerings_on_departure_and_name"
      table.index %i[id agency_id], unique: true, name: "index_offerings_on_id_and_agency_id"
      table.check_constraint "btrim(name) <> '' AND char_length(name) <= 120", name: "offerings_name"
      table.check_constraint "currency ~ '^[A-Z]{3}$'", name: "offerings_currency"
      table.check_constraint "position >= 0 AND lock_version >= 0", name: "offerings_counters"
    end

    create_table :offering_choices, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :offering_id, null: false
      table.string :name, null: false
      table.string :role, null: false
      table.string :scope, null: false
      table.string :pattern, null: false
      table.integer :position, null: false, default: 0
      table.integer :lock_version, null: false, default: 0
      table.timestamps

      table.index %i[offering_id position], name: "index_offering_choices_on_offering_and_position"
      table.index %i[id agency_id], unique: true, name: "index_offering_choices_on_id_and_agency_id"
      table.check_constraint "btrim(name) <> '' AND char_length(name) <= 120", name: "offering_choices_name"
      table.check_constraint "role IN ('included', 'add_on')", name: "offering_choices_role"
      table.check_constraint "scope IN ('per_traveler', 'per_unit', 'per_trip')", name: "offering_choices_scope"
      table.check_constraint "pattern IN ('required_single', 'optional_single', 'optional_multiple')", name: "offering_choices_pattern"
      # BKG-14: optional multiple applies only to add-ons.
      table.check_constraint "pattern <> 'optional_multiple' OR role = 'add_on'", name: "offering_choices_multiple_only_add_ons"
      table.check_constraint "position >= 0 AND lock_version >= 0", name: "offering_choices_counters"
    end

    create_table :offering_options, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :offering_choice_id, null: false
      table.uuid :inventory_group_id, null: false
      table.string :label, null: false
      table.text :description
      table.integer :position, null: false, default: 0
      table.integer :lock_version, null: false, default: 0
      table.timestamps

      table.index %i[offering_choice_id inventory_group_id], unique: true, name: "index_offering_options_one_per_group_in_choice"
      table.index :inventory_group_id, name: "index_offering_options_on_group"
      table.index %i[id agency_id], unique: true, name: "index_offering_options_on_id_and_agency_id"
      table.check_constraint "btrim(label) <> '' AND char_length(label) <= 120", name: "offering_options_label"
      table.check_constraint "position >= 0 AND lock_version >= 0", name: "offering_options_counters"
    end

    create_table :offering_prices, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :offering_option_id, null: false
      table.string :occupancy_position, null: false
      table.uuid :traveler_type_id
      table.bigint :amount_minor_units, null: false
      table.string :currency, null: false
      table.integer :lock_version, null: false, default: 0
      table.timestamps

      table.index %i[offering_option_id occupancy_position traveler_type_id], unique: true, nulls_not_distinct: true,
        name: "index_offering_prices_one_per_option_position_type"
      table.check_constraint "occupancy_position IN (#{POSITIONS.map { |position| quote(position) }.join(", ")})", name: "offering_prices_occupancy_position"
      table.check_constraint "amount_minor_units >= 0", name: "offering_prices_amount"
      table.check_constraint "currency ~ '^[A-Z]{3}$'", name: "offering_prices_currency"
      table.check_constraint "lock_version >= 0", name: "offering_prices_lock_version"
    end

    execute <<~SQL
      ALTER TABLE offerings
        ADD CONSTRAINT fk_offerings_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_offerings_departure_same_agency FOREIGN KEY (departure_id, agency_id) REFERENCES departures (id, agency_id);
      ALTER TABLE offering_choices
        ADD CONSTRAINT fk_offering_choices_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_offering_choices_offering_same_agency FOREIGN KEY (offering_id, agency_id) REFERENCES offerings (id, agency_id);
      ALTER TABLE offering_options
        ADD CONSTRAINT fk_offering_options_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_offering_options_choice_same_agency FOREIGN KEY (offering_choice_id, agency_id) REFERENCES offering_choices (id, agency_id),
        ADD CONSTRAINT fk_offering_options_group_same_agency FOREIGN KEY (inventory_group_id, agency_id) REFERENCES inventory_groups (id, agency_id);
      ALTER TABLE offering_prices
        ADD CONSTRAINT fk_offering_prices_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_offering_prices_option_same_agency FOREIGN KEY (offering_option_id, agency_id) REFERENCES offering_options (id, agency_id),
        ADD CONSTRAINT fk_offering_prices_traveler_type_same_agency FOREIGN KEY (traveler_type_id, agency_id) REFERENCES traveler_types (id, agency_id);

      -- BKG-13: an option draws on inventory of its own offering's Departure.
      CREATE FUNCTION public.reject_offering_option_other_departure() RETURNS trigger
          LANGUAGE plpgsql AS $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM offering_choices c
            JOIN offerings o ON o.id = c.offering_id
            JOIN inventory_groups g ON g.id = NEW.inventory_group_id
            JOIN supplier_arrangements a ON a.id = g.supplier_arrangement_id
          WHERE c.id = NEW.offering_choice_id AND a.departure_id = o.departure_id
        ) THEN
          RAISE EXCEPTION 'offering option % draws on another departure''s inventory', NEW.id;
        END IF;
        RETURN NEW;
      END;
      $$;
      CREATE TRIGGER offering_options_reject_other_departure BEFORE INSERT OR UPDATE ON public.offering_options
        FOR EACH ROW EXECUTE FUNCTION public.reject_offering_option_other_departure();
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
