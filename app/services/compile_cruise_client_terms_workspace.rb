# frozen_string_literal: true

class CompileCruiseClientTermsWorkspace
  def initialize(agency:, offer:, version:)
    @agency = agency
    @offer = offer
    @version = version
  end

  def call
    connection = DetectCruiseServiceConnectionShape.new(agency: @agency, offer: @offer, version: @version).call
    shape = DetectCruiseClientTermShape.new(agency: @agency, offer: @offer, version: @version).call
    categories = connection.choices.map do |choice|
      option = choice[:option]
      binding = choice[:binding]
      resource = @agency.supplier_resources.find(binding.supplier_resource_id)
      bands = CompileCruiseClientTermBandSet.new(
        agency: @agency, arrangement_version: connection.arrangement_version, resource: resource
      ).call
      components = Array(@version.price_definition&.service_offer_price_components).select { |component| component.client_rate_category_key == option.client_rate_category_key }
      saved_bands = components.map(&:occupancy_position_key).uniq
      unsupported = saved_bands - bands.enabled
      {
        option: option,
        binding: binding,
        resource: resource,
        bands: bands,
        components: components,
        unsupported_bands: unsupported,
        states: components.index_with { |component| CompareSupplierCostCopyProvenance.call(component: component, pinned_version_id: binding.supplier_arrangement_version_id, resource_id: resource.id) }
      }
    end
    { connection: connection, shape: shape, categories: categories }
  end
end
