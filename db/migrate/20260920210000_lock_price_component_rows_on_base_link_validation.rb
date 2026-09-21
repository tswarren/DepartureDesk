# frozen_string_literal: true

class LockPriceComponentRowsOnBaseLinkValidation < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE OR REPLACE FUNCTION validate_service_offer_price_component_base() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE
        rec RECORD;
        owner_position integer;
        owner_kind text;
        base_position integer;
        base_treatment text;
      BEGIN
        -- Lock both referenced components in UUID order so a concurrent position or
        -- treatment change cannot validate against this transaction's old snapshot.
        FOR rec IN
          SELECT id, position, calculation_kind, percentage_treatment
            FROM service_offer_price_components
           WHERE id IN (NEW.service_offer_price_component_id, NEW.base_component_id)
             AND service_offer_price_definition_id = NEW.service_offer_price_definition_id
           ORDER BY id
             FOR SHARE
        LOOP
          IF rec.id = NEW.service_offer_price_component_id THEN
            owner_position := rec.position;
            owner_kind := rec.calculation_kind;
          END IF;
          IF rec.id = NEW.base_component_id THEN
            base_position := rec.position;
            base_treatment := rec.percentage_treatment;
          END IF;
        END LOOP;

        IF owner_position IS NULL OR base_position IS NULL OR base_position >= owner_position THEN
          RAISE EXCEPTION 'price component base must be an earlier component in the same definition';
        END IF;
        IF owner_kind <> 'percentage' THEN
          RAISE EXCEPTION 'only percentage price components accept bases';
        END IF;
        IF base_treatment = 'included' THEN
          RAISE EXCEPTION 'an included-tax allocation cannot be a later percentage base';
        END IF;
        RETURN NEW;
      END;
      $$;
    SQL
  end

  def down
    execute <<~SQL
      CREATE OR REPLACE FUNCTION validate_service_offer_price_component_base() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE component_position integer;
      DECLARE component_kind text;
      DECLARE base_position integer;
      DECLARE base_treatment text;
      BEGIN
        SELECT position, calculation_kind INTO component_position, component_kind
          FROM service_offer_price_components
         WHERE id = NEW.service_offer_price_component_id
           AND service_offer_price_definition_id = NEW.service_offer_price_definition_id;
        SELECT position, percentage_treatment INTO base_position, base_treatment
          FROM service_offer_price_components
         WHERE id = NEW.base_component_id
           AND service_offer_price_definition_id = NEW.service_offer_price_definition_id;
        IF component_position IS NULL OR base_position IS NULL OR base_position >= component_position THEN
          RAISE EXCEPTION 'price component base must be an earlier component in the same definition';
        END IF;
        IF component_kind <> 'percentage' THEN
          RAISE EXCEPTION 'only percentage price components accept bases';
        END IF;
        IF base_treatment = 'included' THEN
          RAISE EXCEPTION 'an included-tax allocation cannot be a later percentage base';
        END IF;
        RETURN NEW;
      END;
      $$;
    SQL
  end
end
