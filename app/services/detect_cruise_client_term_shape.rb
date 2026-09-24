# frozen_string_literal: true

class DetectCruiseClientTermShape
  Result = Data.define(:compatible?, :reasons)

  def initialize(agency:, offer:, version:)
    @agency = agency
    @offer = offer
    @version = version
  end

  def call
    connection = DetectCruiseServiceConnectionShape.new(agency: @agency, offer: @offer, version: @version).call
    return Result.new(compatible?: false, reasons: connection.reasons) unless connection.compatible?

    definition = @version.price_definition
    return Result.new(compatible?: true, reasons: []) if definition.nil?
    return Result.new(compatible?: false, reasons: [ "This price is not a calculated Client price." ]) unless definition.calculated?

    keys = connection.choices.map { |choice| choice[:option].client_rate_category_key }
    components = definition.service_offer_price_components.includes(service_offer_price_component_bases: :base_component).to_a
    reasons = []
    reasons << "Percentage Client prices stay in advanced pricing." if components.any?(&:percentage?)
    seen = {}
    components.each do |component|
      key = component.client_rate_category_key
      if key.blank?
        reasons << "A Client price component is not scoped to a cabin category."
        next
      end
      unless keys.include?(key)
        reasons << "A Client price component uses a category this Cruise connection does not offer."
        next
      end
      row_key = component.cruise_client_term_row_key
      if row_key.blank? || !CruiseClientTermRows.known?(row_key)
        reasons << "A Client term row cannot be edited here."
      else
        reasons << "A Client term uses a role this row does not mean." if component.client_role != CruiseClientTermRows.role_for(row_key)
        unless component.calculation_kind == "unit_rate" && component.quantity_basis == "occupancy_positions"
          reasons << "A Client term is not an occupancy unit rate."
        end
        if component.percentage? || component.percentage_treatment.present? || component.rate.present? || component.service_offer_price_component_bases.any?
          reasons << "A Client term uses percentage or base semantics."
        end
      end
      unless CruiseClientTermRows::BANDS.include?(component.occupancy_position_key)
        reasons << "A Client term uses an unsupported traveler position."
      end
      identity = [ key, component.occupancy_position_key, component.cruise_client_term_row_key ]
      reasons << "Two Client terms share the same category, position, and row." if seen[identity]
      seen[identity] = true
      component.service_offer_price_component_bases.each do |link|
        base_key = link.base_component&.client_rate_category_key
        reasons << "A Client price component uses a base from another category." if base_key.blank? || base_key != key
      end
    end
    Result.new(compatible?: reasons.empty?, reasons: reasons.uniq)
  end
end
