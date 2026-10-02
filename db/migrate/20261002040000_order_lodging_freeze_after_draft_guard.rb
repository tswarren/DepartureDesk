# frozen_string_literal: true

class OrderLodgingFreezeAfterDraftGuard < ActiveRecord::Migration[8.1]
  TABLES = %w[
    arrangement_item_definitions
    service_occurrence_definitions
    supplier_resource_definitions
    capacity_pair_definitions
    capacity_pool_definitions
    supplier_cost_sources
    supplier_cost_definitions
    supplier_cost_components
    supplier_deadline_definitions
    supplier_deposit_requirement_definitions
    supplier_deadline_definition_coverage_links
    supplier_deposit_requirement_definition_coverage_links
  ].freeze

  def up
    TABLES.each do |table|
      execute <<~SQL
        DROP TRIGGER #{table}_reject_confirmed_lodging ON public.#{table};
        CREATE TRIGGER #{table}_reject_supplier_confirmed_lodging
          BEFORE INSERT OR UPDATE OR DELETE ON public.#{table}
          FOR EACH ROW EXECUTE FUNCTION reject_confirmed_lodging_definition_mutation();
      SQL
    end
  end

  def down
    TABLES.each do |table|
      execute <<~SQL
        DROP TRIGGER IF EXISTS #{table}_reject_supplier_confirmed_lodging ON public.#{table};
        CREATE TRIGGER #{table}_reject_confirmed_lodging
          BEFORE INSERT OR UPDATE OR DELETE ON public.#{table}
          FOR EACH ROW EXECUTE FUNCTION reject_confirmed_lodging_definition_mutation();
      SQL
    end
  end
end
