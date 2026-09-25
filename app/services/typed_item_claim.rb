# frozen_string_literal: true

module TypedItemClaim
  module_function

  def assert_available!(item, except_offer: nil)
    offers = CruiseServiceConnectionSupport.offers_pinning_item(item, except_offer_id: except_offer&.id)
    return if offers.empty?

    if offers.one?
      raise AgencyCommand::Error.new(
        "This supplier item already has a Client service (#{offers.first.name}). Open that service instead of creating another.",
        code: :conflict
      )
    end

    raise AgencyCommand::Error.new(
      "More than one Client service already uses this supplier item. Open advanced Service Offer editing.",
      code: :invalid
    )
  end
end
