# "Ready to confirm?" for a draft supplier arrangement (SUP-11, SUP-12) and
# "Ready to sell?" for a draft Departure (DEP-03, DEP-05): what the step
# requires, read from the same checks the commands make, then what is
# usually set up first but not required. Nothing here adds a requirement.
module SetupChecklistHelper
  ChecklistItem = Data.define(:label, :done, :detail, :href, :required)

  def arrangement_checklist(departure, arrangement, view_costs:)
    blockers = arrangement.confirmation_blockers
    groups = arrangement.inventory_groups.to_a
    group_blockers = groups.flat_map(&:confirmation_blockers)
    edit = edit_departure_arrangement_path(departure, arrangement)
    items = [
      ChecklistItem.new(label: "The supplier's group or confirmation reference", done: arrangement.group_reference.present?,
        detail: arrangement.group_reference, href: edit, required: true),
      ChecklistItem.new(label: "Payee account", done: arrangement.payee_account_id.present?,
        detail: arrangement.payee_account && "#{arrangement.payee_account.name} (#{arrangement.payee_account.currency})", href: edit, required: true),
      ChecklistItem.new(label: "Inventory", done: groups.any? && group_blockers.empty?,
        detail: groups.empty? ? "Add at least one group." : (group_blockers.any? ? group_blockers.to_sentence : inventory_summary(groups)),
        href: departure_arrangement_inventory_path(departure, arrangement), required: true)
    ]
    rate_blockers = blockers.grep(/\ARemove the guest/)
    items << ChecklistItem.new(label: "Rates beyond a unit's positions", done: false, detail: rate_blockers.to_sentence, href: departure_arrangement_costs_path(departure, arrangement), required: true) if rate_blockers.any?
    if view_costs
      gaps = SupplierRateGrid.new(arrangement).gaps.size
      rated = arrangement.rate_lines.any?
      items << ChecklistItem.new(label: "Supplier rates", done: rated && gaps.zero?,
        detail: rated ? (gaps.zero? ? "Every fare entered." : "#{pluralize(gaps, "fare")} not entered yet.") : "None yet. Booking confirmation works out supplier cost from them.",
        href: edit_departure_arrangement_rates_path(departure, arrangement), required: false)
      payments = arrangement.schedule_lines.size
      items << ChecklistItem.new(label: "Payments", done: payments.positive?,
        detail: payments.positive? ? "#{pluralize(payments, "payment")} set up." : "None yet, such as deposits the supplier asks for.", href: departure_arrangement_payments_path(departure, arrangement), required: false)
    end
    items
  end

  def departure_checklist(departure)
    blockers = departure.ready_to_sell_blockers
    edit = edit_departure_path(departure)
    owned = ->(*texts) { blockers.select { |blocker| texts.any? { |text| blocker.start_with?(text) } } }
    required = [
      [ "Name", owned.call("Enter a name"), departure.name ],
      [ "Dates", owned.call("Enter a start date", "End date"), departure.schedule_label ],
      [ "Time zone", owned.call("Enter a recognized time zone"), departure.time_zone ],
      [ "Operating currency", owned.call("Enter a supported operating currency"), departure.operating_currency ]
    ].map { |label, mine, value| ChecklistItem.new(label:, done: mine.empty?, detail: mine.any? ? mine.to_sentence : value, href: edit, required: true) }

    offering = departure.offerings.first
    package_gaps = offering ? offering.booking_blockers : [ "Add a package." ]
    terms = departure.current_client_terms
    terms_gaps = terms ? terms.booking_blockers : [ "Set up client terms." ]
    arrangements = departure.supplier_arrangements.reject(&:cancelled?)
    confirmed = arrangements.count(&:confirmed?)
    required + [
      ChecklistItem.new(label: "A package clients can book", done: package_gaps.empty?, detail: package_gaps.empty? ? offering.name : package_gaps.first(3).to_sentence,
        href: departure_offerings_path(departure), required: false),
      ChecklistItem.new(label: "Client terms", done: terms_gaps.empty?, detail: terms_gaps.empty? ? "Version #{terms.version_number}" : terms_gaps.to_sentence,
        href: departure_client_terms_path(departure), required: false),
      ChecklistItem.new(label: "Supplier arrangements confirmed", done: arrangements.any? && confirmed == arrangements.size,
        detail: arrangements.empty? ? "None yet." : "#{confirmed} of #{arrangements.size} confirmed.", href: departure_arrangements_path(departure), required: false)
    ]
  end

  private

  def inventory_summary(groups)
    counted = groups.sum { |group| group.quantity.to_i }
    "#{pluralize(groups.size, "group")}#{", #{counted} units or places" if counted.positive?}."
  end
end
