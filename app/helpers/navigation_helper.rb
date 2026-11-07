module NavigationHelper
  # Arrangement screens live under a Departure, whatever their controller name.
  DEPARTURE_AREA = %w[
    supplier_arrangements supplier_arrangement_confirmations supplier_arrangement_discards supplier_rate_lines
    supplier_deadlines arrangement_documents inventory_groups capacity_rules capacity_events
    cost_lines schedule_lines trigger_events direct_amounts_due
    offerings offering_choices offering_options offering_prices client_cancellation_tiers client_schedule_lines
    departure_bookings
  ].freeze

  def primary_navigation_current?(item)
    case item.to_sym
    when :dashboard
      controller_name == "dashboard"
    when :tasks
      controller_path == "tasks" || controller_path.start_with?("task_")
    when :administration
      controller_path.start_with?("administration/")
    when :clients
      controller_path.in?(%w[clients client_people travelers traveler_links client_trips client_bookings booking_travelers choice_selections booking_holds booking_discards booking_confirmations]) || controller_path.start_with?("client_person_")
    when :suppliers
      (controller_path == "suppliers" || controller_path.start_with?("supplier_")) && !DEPARTURE_AREA.include?(controller_path)
    when :departures
      controller_path == "departures" || controller_path.start_with?("departure_") || DEPARTURE_AREA.include?(controller_path)
    else
      false
    end
  end

  def primary_nav_current_for(item)
    "page" if primary_navigation_current?(item)
  end
end
