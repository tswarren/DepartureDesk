# Shared steps for supplier arrangement commands (ADR 0018). Lock order:
# agency, Departure, arrangement, then inventory and pools last.
module ArrangementCommandSupport
  include DepartureCommandSupport

  ATTRIBUTES = %w[
    payee_account_id group_reference reservation_scope obligation_shape default_availability_promise
    covered_services terms
  ].freeze

  private

  def lock_arrangement_context!
    lock_authorized_agency!(:manage_arrangements)
    departure = @agency.departures.lock.find(@departure.id)
    raise AgencyCommand::Error.new("A departed departure's arrangements cannot change.", code: :invalid_state) if departure.departed?

    departure
  end

  def lock_arrangement!(departure)
    departure.supplier_arrangements.lock.find(@arrangement.id)
  end

  def ensure_draft!(arrangement)
    return if arrangement.draft?

    raise AgencyCommand::Error.new("Only a draft arrangement can be changed this way.", code: :invalid_state)
  end

  def arrangement_attributes(supplier)
    attrs = @attributes.slice(*ATTRIBUTES)
    attrs.transform_values! { |value| value.is_a?(String) ? value.strip.presence : value }
    if attrs.key?("payee_account_id") && attrs["payee_account_id"].present?
      uuid = parse_optional_uuid(attrs["payee_account_id"], "Payee account")
      account = supplier.payee_accounts.find_by(id: uuid)
      raise AgencyCommand::Error.new("Choose one of this supplier's payee accounts.", code: :invalid) if account.nil?
    end
    attrs.delete("reservation_scope") if attrs["reservation_scope"].nil?
    attrs.delete("default_availability_promise") if attrs["default_availability_promise"].nil?
    attrs
  end

  def ensure_departure_currency!(departure)
    return departure.operating_currency if departure.operating_currency.present?

    raise AgencyCommand::Error.new("Set the departure's operating currency before adding an arrangement.", code: :invalid_state)
  end
end
