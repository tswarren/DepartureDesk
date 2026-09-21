# frozen_string_literal: true

class ValidatePriceComponentLinkInvariantsOnUpdate < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE FUNCTION validate_service_offer_price_component_link_invariants() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE
        link RECORD;
        owner_position integer;
        owner_kind text;
        base_position integer;
        base_treatment text;
      BEGIN
        IF TG_OP = 'UPDATE'
           AND NEW.position IS NOT DISTINCT FROM OLD.position
           AND NEW.percentage_treatment IS NOT DISTINCT FROM OLD.percentage_treatment
           AND NEW.calculation_kind IS NOT DISTINCT FROM OLD.calculation_kind THEN
          RETURN NEW;
        END IF;

        FOR link IN
          SELECT *
            FROM service_offer_price_component_bases
           WHERE service_offer_price_component_id = NEW.id
              OR base_component_id = NEW.id
        LOOP
          SELECT position, calculation_kind INTO owner_position, owner_kind
            FROM service_offer_price_components
           WHERE id = link.service_offer_price_component_id;
          SELECT position, percentage_treatment INTO base_position, base_treatment
            FROM service_offer_price_components
           WHERE id = link.base_component_id;

          IF NEW.id = link.service_offer_price_component_id THEN
            owner_position := NEW.position;
            owner_kind := NEW.calculation_kind;
          END IF;
          IF NEW.id = link.base_component_id THEN
            base_position := NEW.position;
            base_treatment := NEW.percentage_treatment;
          END IF;

          IF owner_position IS NULL OR base_position IS NULL OR base_position >= owner_position THEN
            RAISE EXCEPTION 'price component base must be an earlier component in the same definition';
          END IF;
          IF owner_kind <> 'percentage' THEN
            RAISE EXCEPTION 'only percentage price components accept bases';
          END IF;
          IF base_treatment = 'included' THEN
            RAISE EXCEPTION 'an included-tax allocation cannot be a later percentage base';
          END IF;
        END LOOP;

        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER service_offer_price_components_validate_links
        BEFORE UPDATE ON public.service_offer_price_components
        FOR EACH ROW EXECUTE FUNCTION validate_service_offer_price_component_link_invariants();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS service_offer_price_components_validate_links
        ON public.service_offer_price_components;
      DROP FUNCTION IF EXISTS validate_service_offer_price_component_link_invariants();
    SQL
  end
end
