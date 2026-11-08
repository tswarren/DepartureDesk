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

  # Each tier as the window it covers, latest first, with the dates of that
  # window when the Departure's start is known (BKG-31): "61 to 119 days
  # before departure (Jul 10 to Sep 6, 2027): 50% of the service's charge".
  def tier_sentences(tiers, starts_on = nil)
    ordered = tiers.sort_by { |tier| -tier.min_days_before_departure }
    date = ->(days) { (starts_on - days).strftime("%b %-d, %Y") }
    ordered.each_with_index.map do |tier, index|
      low = tier.min_days_before_departure
      high = index.zero? ? nil : ordered[index - 1].min_days_before_departure - 1
      window = if high.nil?
        low.zero? ? "Up to departure" : "#{pluralize(low, "day")} or more before departure#{" (by #{date.call(low)})" if starts_on}"
      elsif low.zero?
        "#{pluralize(high, "day")} or fewer before departure#{" (from #{date.call(high)})" if starts_on}"
      else
        "#{low} to #{pluralize(high, "day")} before departure#{" (#{date.call(high)} to #{date.call(low)})" if starts_on}"
      end
      "#{window}: #{tier_charge(tier)}"
    end
  end

  def tier_charge(tier)
    case tier.charge_kind
    when "percentage" then "#{tier.percentage.to_s("F").sub(/\.0\z/, "")}% of the service's charge"
    when "fixed_per_traveler" then "#{Money.new(tier.amount_minor_units, tier.currency).format} for each traveler"
    else "#{Money.new(tier.amount_minor_units, tier.currency).format} for each #{service_category_label(tier.service_category).downcase} unit"
    end
  end

  # A payment schedule line as one sentence (CMN-09): "$500.00 for each
  # cruise unit, due when the booking is confirmed. It doesn't count as
  # acceptance."
  def client_schedule_sentence(line, starts_on = nil)
    money = line.amount_minor_units && Money.new(line.amount_minor_units, line.currency).format
    how = case line.basis
    when "per_traveler" then "#{money} for each traveler"
    when "per_unit" then "#{money} for each #{service_category_label(line.service_category).downcase} unit"
    when "per_booking" then "#{money} for the booking"
    when "percentage" then "#{line.percentage.to_s("F").sub(/\.0\z/, "")}% of the booking total"
    else "Whatever remains"
    end
    due = case line.due_rule
    when "at_confirmation" then "due when the booking is confirmed"
    when "days_before_departure"
      "due #{pluralize(line.days_before_departure, "day")} before departure#{": #{(starts_on - line.days_before_departure).strftime("%b %-d, %Y")}" if starts_on}"
    else "due #{line.due_on.strftime("%b %-d, %Y")}"
    end
    "#{how}, #{due}. #{line.counts_as_acceptance ? "Receiving it counts as the client's acceptance." : "It doesn't count as acceptance."}"
  end

  def package_group_options(departure)
    InventoryGroup.joins(supplier_arrangement: :supplier).where(supplier_arrangements: { departure_id: departure.id })
      .where.not(supplier_arrangements: { status: "cancelled" }).order("suppliers.display_name", "inventory_groups.position")
      .pluck("inventory_groups.label", "suppliers.display_name", "inventory_groups.id").map { |label, supplier, id| [ "#{label} · #{supplier}", id ] }
  end
end
