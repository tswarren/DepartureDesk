# frozen_string_literal: true

class CruiseCategoryOptionPrice
  Result = Data.define(:status, :reason)

  def self.call(option:, version:)
    return Result.new(status: :priced, reason: nil) if option.price_effect_minor_units.present? || option.price_effect_minor_units == 0

    key = option.client_rate_category_key
    definition = version.price_definition
    return Result.new(status: :incomplete, reason: :ordinary_option) if key.blank?

    has_base = definition&.service_offer_price_components&.any? do |component|
      component.client_role == "base_price" && component.client_rate_category_key == key
    end
    return Result.new(status: :missing_base_price, reason: :category_base_price_missing) unless has_base

    supported = definition.calculated? && definition.service_offer_price_components.none?(&:percentage?)
    return Result.new(status: :incomplete, reason: :unsupported_graph) unless supported
    return Result.new(status: :incomplete, reason: :unreachable_key) unless version.choice_options.any? { |choice| choice.id == option.id && choice.client_rate_category_key == key }

    Result.new(status: :waived, reason: :category_price)
  end
end
