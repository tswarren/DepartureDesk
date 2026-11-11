module NavigationHelper
  # Arrangement screens live under a Departure, whatever their controller name.
  DEPARTURE_AREA = %w[
    supplier_arrangements supplier_arrangement_confirmations supplier_arrangement_discards supplier_rates supplier_rate_patterns supplier_rate_bands supplier_rate_copies
    supplier_deadlines arrangement_documents inventory_groups capacity_rules capacity_events
    cost_lines schedule_lines trigger_events direct_amounts_due
    offerings offering_choices offering_options offering_prices offering_publications client_cancellation_tiers client_schedule_lines
    departure_bookings departure_client_terms_next_versions
  ].freeze
  # Trip and booking screens sit under the trip's Departure when it has one,
  # as their breadcrumbs do (UX consolidation audit A5), else under Clients.
  TRIP_AREA = %w[
    client_trips client_bookings client_payments client_payment_reversals client_credit_applications receipts
    booking_acceptance_evidence booking_acceptances booking_confirmations booking_discards booking_holds booking_supplier_costs booking_supplier_reservations
    booking_traveler_additions booking_traveler_batches booking_traveler_moves booking_travelers choice_selection_ranges choice_selections
    booking_assignments booking_sellers commission_confirmations installment_proposals
  ].freeze

  def primary_navigation_current?(item)
    case item.to_sym
    when :dashboard
      controller_name == "dashboard"
    when :tasks
      controller_path == "tasks" || controller_path.start_with?("task_")
    when :administration
      controller_path.start_with?("administration/")
    when :resellers
      controller_path == "resellers"
    when :clients
      (controller_path.in?(%w[clients client_people travelers traveler_links]) || controller_path.start_with?("client_person_") || TRIP_AREA.include?(controller_path)) && !trip_on_departure?
    when :suppliers
      (controller_path == "suppliers" || controller_path.start_with?("supplier_")) && !DEPARTURE_AREA.include?(controller_path)
    when :departures
      controller_path == "departures" || controller_path.start_with?("departure_") || DEPARTURE_AREA.include?(controller_path) || trip_on_departure?
    else
      false
    end
  end

  def trip_on_departure?
    return false unless TRIP_AREA.include?(controller_path)

    trip = @booking&.client_trip || @trip || @receipt&.client_payment&.client_trip
    trip.nil? ? controller_path != "client_trips" : trip.departure_id.present?
  end

  def primary_nav_current_for(item)
    "page" if primary_navigation_current?(item)
  end

  # One trail to a trip (UX consolidation audit A5): through its Departure's
  # bookings when it has one, else through its client. A booking sits under
  # its trip.
  def trip_trail(trip, current: false)
    departure = trip.departure
    base = if departure
      [ [ "Departures", departures_path ], [ departure.display_reference, departure_path(departure) ], [ "Bookings", departure_bookings_path(departure) ] ]
    else
      client = trip.client
      [ [ "Clients", clients_path ], [ client.source.display_name, client.client_person ? client_person_path(client.client_person) : client_organization_path(client.client_organization) ] ]
    end
    base + [ [ trip.trip_reference, (client_trip_path(trip) unless current) ] ]
  end

  def booking_trail(booking, current: false)
    trip_trail(booking.client_trip) + [ [ booking.booking_reference, (client_booking_path(booking) unless current) ] ]
  end
end
