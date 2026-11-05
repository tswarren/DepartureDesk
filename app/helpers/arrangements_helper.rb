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

  SERVICE_CATEGORY_LABELS = {
    "hotel" => "Hotel", "all_inclusive_resort" => "All-inclusive resort", "cruise" => "Cruise", "air" => "Air", "rail" => "Rail",
    "transportation" => "Transportation", "activity" => "Activity", "meal" => "Meal", "insurance" => "Insurance"
  }.freeze
  REPRESENTATION_LABELS = { "unit_shells" => "Unit shells", "capacity_pool" => "Capacity pool", "none" => "No shared inventory" }.freeze

  def service_category_label(value) = SERVICE_CATEGORY_LABELS.fetch(value.to_s)
  def representation_label(value) = REPRESENTATION_LABELS.fetch(value.to_s)

  # "Nov 05, 2027 2:00 PM – Nov 05, 2027 6:30 PM America/New_York"
  def group_service_dates(group)
    return "Not set" if group.starts_on.blank?

    start = [ group.starts_on.to_fs(:long), group.starts_at_time&.strftime("%-l:%M %p") ].compact.join(" ")
    finish = [ group.ends_on.to_fs(:long), group.ends_at_time&.strftime("%-l:%M %p") ].compact.join(" ")
    "#{start} – #{finish}#{" (#{group.time_zone})" if group.time_zone}"
  end

  def group_quantity_label(group)
    return "No balance (#{availability_promise_label(group.availability_promise)})" unless group.numeric?
    return "Not set" if group.quantity.blank?

    group.represented_as_unit_shells? ? "#{pluralize(group.quantity, "unit")}#{", #{pluralize(group.positions_per_unit, "position")} each" if group.positions_per_unit}" : "#{group.quantity} places"
  end

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
