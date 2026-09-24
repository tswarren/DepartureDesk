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
    return Result.new(compatible?: false, reasons: [ "Percentage Client prices stay in advanced pricing." ]) if definition.service_offer_price_components.any?(&:percentage?)

    keys = connection.choices.map { |choice| choice[:option].client_rate_category_key }
    reasons = []
    definition.service_offer_price_components.each do |component|
      next if component.client_rate_category_key.blank?
      next unless keys.include?(component.client_rate_category_key)
      reasons << "A Client term is missing its row." if component.cruise_client_term_row_key.blank?
      reasons << "A Client term uses an unsupported row." if component.cruise_client_term_row_key.present? && !CruiseClientTermRows.known?(component.cruise_client_term_row_key)
      reasons << "A Client term uses an unsupported traveler position." unless CruiseClientTermRows::BANDS.include?(component.occupancy_position_key)
    end
    Result.new(compatible?: reasons.empty?, reasons: reasons.uniq)
  end
end
