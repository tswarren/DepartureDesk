# frozen_string_literal: true

module OfferPublicationFingerprint
  module_function

  def for_service_offer_version(version)
    bindings = version.source_bindings.order(:position).map do |binding|
      {
        "binding_id" => binding.id,
        "supplier_arrangement_version_id" => binding.supplier_arrangement_version_id,
        "arrangement_item_definition_id" => binding.arrangement_item_definition_id,
        "service_occurrence_definition_id" => binding.service_occurrence_definition_id,
        "supplier_resource_definition_id" => binding.supplier_resource_definition_id,
        "capacity_pool_definition_id" => binding.capacity_pool_definition_id,
        "membership_kind" => binding.membership_kind
      }
    end
    {
      "service_offer_version_id" => version.id,
      "price_definition_id" => version.price_definition&.id,
      "bindings" => bindings,
      "choice_option_ids" => version.choice_options.order(:position).pluck(:id)
    }
  end

  def for_package_version(version)
    {
      "package_version_id" => version.id,
      "price_definition_id" => version.price_definition&.id,
      "term_resolution_ids" => version.term_resolutions.order(:id).pluck(:id),
      "inclusions" => version.inclusions.order(:position).map { |row|
        {
          "inclusion_id" => row.id,
          "service_offer_version_id" => row.service_offer_version_id,
          "placement" => row.placement,
          "origin" => row.origin
        }
      }
    }
  end
end
