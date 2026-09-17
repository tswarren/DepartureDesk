require "digest"
require "json"

class SupplierCostDefinitionFingerprint
  COMPONENT_FIELDS = %i[
    label economic_role calculation_kind amount_minor_units rate minimum_minor_units
    minimum_quantity quantity_basis participant_category_id occupancy_position_from
    occupancy_position_to percentage_treatment pass_through
  ].freeze

  def self.call(definition, components: nil, category_labels: nil)
    component_records = components || definition.supplier_cost_components.order(:position, :id).to_a
    components = component_records.sort_by { |component| [ component.position, component.id ] }.map do |component|
      COMPONENT_FIELDS.to_h { |field| [ field, component.public_send(field) ] }.merge(
        bases: component.supplier_cost_component_bases.sort_by { |base| [ base.position, base.id ] }.map do |base|
          [ base.base_component_id, base.direction, base.position ]
        end
      )
    end
    category_ids = components.filter_map { |component| component[:participant_category_id] }.uniq
    categories = if category_labels
      category_ids.sort.map { |id| [ id, category_labels[id] ] }
    else
      SupplierCostParticipantCategory.where(id: category_ids).order(:id).pluck(:id, :label)
    end
    payload = {
      definition: definition.attributes.slice("stage", "mode", "currency", "rounding_mode", "zero_cost_reason"),
      source: definition.supplier_cost_source.attributes.slice(
        "arrangement_item_id", "service_occurrence_id", "supplier_resource_id", "charging_supplier_id"
      ),
      components: components,
      categories: categories
    }

    "sha256:#{Digest::SHA256.hexdigest(JSON.generate(deep_sort(payload)))}"
  end

  def self.deep_sort(value)
    case value
    when Hash
      value.each_with_object({}) do |(key, item), sorted|
        sorted[key.to_s] = deep_sort(item)
      end.sort.to_h
    when Array
      value.map { |item| deep_sort(item) }
    else
      value
    end
  end
end
