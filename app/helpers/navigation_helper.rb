module NavigationHelper
  def primary_navigation_current?(item)
    case item.to_sym
    when :dashboard
      controller_name == "dashboard"
    when :administration
      controller_path.start_with?("administration/")
    when :clients
      controller_path.in?(%w[clients client_people]) || controller_path.start_with?("client_person_")
    when :suppliers
      controller_path == "suppliers" || supplier_directory_controller?
    when :departures
      controller_path == "departures" || controller_path.start_with?("departure_") || supplier_planning_controller?
    else
      false
    end
  end

  def primary_nav_current_for(item)
    "page" if primary_navigation_current?(item)
  end

  def supplier_directory_controller?
    controller_path.start_with?("supplier_") && !supplier_planning_controller?
  end

  def supplier_planning_controller?
    controller_path.in?(%w[
      supplier_arrangements
      arrangement_items
      service_occurrences
      supplier_resources
    ])
  end
end
