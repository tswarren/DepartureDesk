# frozen_string_literal: true

module CruiseServiceConnectionSupport
  GROUP_NAME = "Cabin category"
  RATE_KEY_FORMAT = /\Acruise_cabin:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

  module_function

  def rate_key_for(option_id)
    "cruise_cabin:#{option_id}"
  end

  def option_name_for(resource_definition)
    code = resource_definition.supplier_code.to_s.strip
    name = resource_definition.name.to_s.strip
    return name if code.blank?
    return code if name.blank?

    "#{code} — #{name}"
  end

  def offers_pinning_item(item, except_offer_id: nil)
    claimed_ids = ServiceOffer.where(intended_arrangement_item_id: item.id).pluck(:id)
    draft_ids = ServiceOffer.joins(versions: :source_bindings)
      .where(service_offer_versions: { status: "draft" })
      .where(service_offer_source_bindings: { arrangement_item_id: item.id })
      .distinct
      .pluck(:id)
    published_ids = ServiceOffer.joins(:source_bindings)
      .where(service_offer_source_bindings: { arrangement_item_id: item.id })
      .where("service_offer_source_bindings.service_offer_version_id = service_offers.current_published_version_id")
      .distinct
      .pluck(:id)
    ids = (claimed_ids + draft_ids + published_ids).uniq
    ids.delete(except_offer_id) if except_offer_id
    ServiceOffer.where(id: ids).order(:name, :id).to_a
  end

  def assert_item_available!(item, except_offer: nil)
    offers = offers_pinning_item(item, except_offer_id: except_offer&.id)
    return if offers.empty?

    if offers.one?
      offer = offers.first
      raise AgencyCommand::Error.new(
        "This cruise already has a Client service (#{offer.name}). Open that service instead of creating another.",
        code: :conflict
      )
    end

    raise AgencyCommand::Error.new(
      "More than one Client service already uses this cruise. Open advanced Service Offer editing.",
      code: :invalid
    )
  end
end
