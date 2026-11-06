module PackageHelper
  ROLE_LABELS = { "included" => "Included", "add_on" => "Add-on" }.freeze
  SCOPE_LABELS = { "per_traveler" => "Per traveler", "per_unit" => "Per unit", "per_trip" => "Per trip" }.freeze
  PATTERN_LABELS = { "required_single" => "Required, choose one", "optional_single" => "Optional, choose at most one", "optional_multiple" => "Optional, choose any" }.freeze
  CHARGE_KIND_LABELS = { "percentage" => "Percentage of the service's charge", "fixed_per_traveler" => "Fixed amount per traveler", "fixed_per_unit" => "Fixed amount per unit" }.freeze
  SCHEDULE_BASIS_LABELS = {
    "per_traveler" => "Fixed amount per traveler", "per_unit" => "Fixed amount per unit", "per_booking" => "Fixed amount per booking",
    "percentage" => "Percentage of the booking total", "balance" => "The balance"
  }.freeze
  SCHEDULE_DUE_LABELS = { "at_confirmation" => "At confirmation", "days_before_departure" => "Days before departure", "fixed_date" => "On a date" }.freeze

  def choice_summary(choice)
    "#{ROLE_LABELS.fetch(choice.role)} · #{SCOPE_LABELS.fetch(choice.scope)} · #{PATTERN_LABELS.fetch(choice.pattern)}"
  end

  # "1st guest $3,385.00; Any position, Child 0–4 $0.00"
  def price_summary(option)
    return "No prices yet" if option.prices.empty?

    option.prices.sort_by(&:sort_key).map do |price|
      label = [ OfferingPrice::POSITION_LABELS.fetch(price.occupancy_position), price.traveler_type&.name ].compact.join(", ")
      "#{label} #{Money.new(price.amount_minor_units, price.currency).format}"
    end.join("; ")
  end

  # "120 or more days before departure: 10%"
  def tier_summary(tier)
    days = tier.min_days_before_departure.zero? ? "Up to departure" : "#{pluralize(tier.min_days_before_departure, "day")} or more before departure"
    charge = case tier.charge_kind
    when "percentage" then "#{tier.percentage.to_s("F").sub(/\.0\z/, "")}% of the service's charge"
    when "fixed_per_traveler" then "#{Money.new(tier.amount_minor_units, tier.currency).format} per traveler"
    else "#{Money.new(tier.amount_minor_units, tier.currency).format} per #{service_category_label(tier.service_category).downcase} unit"
    end
    "#{days}: #{charge}"
  end

  def schedule_line_amount_label(line)
    case line.basis
    when "per_traveler" then "#{Money.new(line.amount_minor_units, line.currency).format} per traveler"
    when "per_unit" then "#{Money.new(line.amount_minor_units, line.currency).format} per #{service_category_label(line.service_category).downcase} unit"
    when "per_booking" then "#{Money.new(line.amount_minor_units, line.currency).format} per booking"
    when "percentage" then "#{line.percentage.to_s("F").sub(/\.0\z/, "")}% of the booking total"
    else "The balance"
    end
  end

  def schedule_line_due_label(line)
    case line.due_rule
    when "at_confirmation" then "At confirmation"
    when "days_before_departure" then "#{pluralize(line.days_before_departure, "day")} before departure"
    else line.due_on.to_fs(:long)
    end
  end

  def package_group_options(departure)
    InventoryGroup.joins(supplier_arrangement: :supplier).where(supplier_arrangements: { departure_id: departure.id })
      .where.not(supplier_arrangements: { status: "cancelled" }).order("suppliers.display_name", "inventory_groups.position")
      .pluck("inventory_groups.label", "suppliers.display_name", "inventory_groups.id").map { |label, supplier, id| [ "#{label} · #{supplier}", id ] }
  end
end
