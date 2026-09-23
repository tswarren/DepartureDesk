# frozen_string_literal: true

class AddCruiseServiceConnectionClaims < ActiveRecord::Migration[8.1]
  def up
    change_table :service_offer_choice_options, bulk: true do |table|
      table.string :client_rate_category_key, limit: 80
    end
    add_check_constraint :service_offer_choice_options,
      "client_rate_category_key IS NULL OR (btrim(client_rate_category_key) <> '' AND char_length(client_rate_category_key) <= 80)",
      name: "service_offer_choice_options_rate_key"
    add_index :service_offer_choice_options,
      [ :service_offer_version_id, :client_rate_category_key ],
      unique: true,
      where: "client_rate_category_key IS NOT NULL",
      name: "index_so_choice_options_on_rate_key"

    change_table :service_offers, bulk: true do |table|
      table.uuid :intended_arrangement_item_id
      table.uuid :intended_supplier_arrangement_id
    end
    add_check_constraint :service_offers,
      "(intended_arrangement_item_id IS NULL AND intended_supplier_arrangement_id IS NULL) OR " \
        "(intended_arrangement_item_id IS NOT NULL AND intended_supplier_arrangement_id IS NOT NULL)",
      name: "service_offers_intended_item_pair"
    add_index :service_offers, :intended_arrangement_item_id,
      unique: true,
      where: "intended_arrangement_item_id IS NOT NULL",
      name: "index_service_offers_on_intended_item"
    add_foreign_key :service_offers, :arrangement_items,
      column: [ :intended_arrangement_item_id, :intended_supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "service_offers_intended_item_fk"

    execute <<~SQL
      CREATE FUNCTION public.reject_service_offer_item_claim_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE
        live_version_count integer;
      BEGIN
        IF OLD.intended_arrangement_item_id IS NULL
           AND OLD.intended_supplier_arrangement_id IS NULL THEN
          RETURN NEW;
        END IF;

        IF NEW.intended_arrangement_item_id IS NOT DISTINCT FROM OLD.intended_arrangement_item_id
           AND NEW.intended_supplier_arrangement_id IS NOT DISTINCT FROM OLD.intended_supplier_arrangement_id THEN
          RETURN NEW;
        END IF;

        IF NEW.intended_arrangement_item_id IS NULL
           AND NEW.intended_supplier_arrangement_id IS NULL THEN
          SELECT COUNT(*) INTO live_version_count
            FROM public.service_offer_versions
           WHERE service_offer_id = NEW.id
             AND status IS DISTINCT FROM 'abandoned';

          IF live_version_count > 0 THEN
            RAISE EXCEPTION 'service offer item claim can be cleared only when every version is abandoned';
          END IF;

          RETURN NEW;
        END IF;

        RAISE EXCEPTION 'service offer item claim cannot be reassigned';
      END;
      $$;

      CREATE TRIGGER service_offers_reject_item_claim_change
        BEFORE UPDATE ON public.service_offers
        FOR EACH ROW EXECUTE FUNCTION public.reject_service_offer_item_claim_change();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS service_offers_reject_item_claim_change ON public.service_offers;
      DROP FUNCTION IF EXISTS public.reject_service_offer_item_claim_change();
    SQL
    remove_foreign_key :service_offers, name: "service_offers_intended_item_fk"
    remove_index :service_offers, name: "index_service_offers_on_intended_item"
    remove_check_constraint :service_offers, name: "service_offers_intended_item_pair"
    remove_column :service_offers, :intended_supplier_arrangement_id
    remove_column :service_offers, :intended_arrangement_item_id
    remove_index :service_offer_choice_options, name: "index_so_choice_options_on_rate_key"
    remove_check_constraint :service_offer_choice_options, name: "service_offer_choice_options_rate_key"
    remove_column :service_offer_choice_options, :client_rate_category_key
  end
end
