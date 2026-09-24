# frozen_string_literal: true

class CruiseCategoryOptionPrice
  Result = Data.define(:status, :reason)

  def self.call(option:, version:)
    return Result.new(status: :priced, reason: nil) if option.price_effect_minor_units.present? || option.price_effect_minor_units == 0

    key = option.client_rate_category_key
    return Result.new(status: :incomplete, reason: :ordinary_option) if key.blank?
    return Result.new(status: :incomplete, reason: :ordinary_option) unless CruiseServiceConnectionSupport::RATE_KEY_FORMAT.match?(key)

    connection = DetectCruiseServiceConnectionShape.new(
      agency: version.agency, offer: version.service_offer, version: version
    ).call
    connected = connection.compatible? && connection.choices.any? { |choice| choice[:option].id == option.id }
    return Result.new(status: :incomplete, reason: :ordinary_option) unless connected

    definition = version.price_definition
    has_base = definition&.service_offer_price_components&.any? do |component|
      component.client_role == "base_price" && component.client_rate_category_key == key
    end
    return Result.new(status: :missing_base_price, reason: :category_base_price_missing) unless has_base

    supported = definition.calculated? && definition.service_offer_price_components.none?(&:percentage?)
    return Result.new(status: :incomplete, reason: :unsupported_graph) unless supported

    Result.new(status: :waived, reason: :category_price)
  end
end
