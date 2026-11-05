module ArrangementsHelper
  ARRANGEMENT_STATUS_LABELS = { "draft" => "Draft", "confirmed" => "Confirmed", "closed" => "Closed", "cancelled" => "Cancelled" }.freeze
  RESERVATION_SCOPE_LABELS = {
    "arrangement" => "Shared across the arrangement",
    "per_unit" => "Tracked per unit",
    "none" => "Not tracked below the arrangement"
  }.freeze
  OBLIGATION_SHAPE_LABELS = {
    "per_unit_used" => "Pay per unit used",
    "committed_quantity" => "Committed quantity",
    "fixed_resource_charge" => "Fixed charge for a whole resource",
    "minimum_pickup" => "Minimum pickup",
    "mixed" => "Mixed"
  }.freeze
  AVAILABILITY_PROMISE_LABELS = {
    "firm_block" => "Firm block",
    "releasable_block" => "Releasable block",
    "courtesy_option" => "Courtesy or option",
    "on_request" => "On request",
    "rate_only" => "Rate only"
  }.freeze

  def arrangement_status_badge(arrangement)
    modifier = { "draft" => "neutral", "confirmed" => "success", "closed" => "info", "cancelled" => "danger" }.fetch(arrangement.status)
    status_badge(ARRANGEMENT_STATUS_LABELS.fetch(arrangement.status), modifier:)
  end

  def reservation_scope_label(value) = RESERVATION_SCOPE_LABELS.fetch(value.to_s, "—")
  def obligation_shape_label(value) = value.present? ? OBLIGATION_SHAPE_LABELS.fetch(value.to_s) : "Not set"
  def availability_promise_label(value) = AVAILABILITY_PROMISE_LABELS.fetch(value.to_s)

  def arrangement_supplier_options(departure)
    taken = departure.supplier_arrangements.live.pluck(:supplier_id)
    Current.agency.suppliers.where(status: "active").where.not(id: taken).order(:display_name)
      .map { |supplier| [ supplier.display_name_for_directory, supplier.id ] }
  end
end
