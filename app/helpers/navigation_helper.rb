module NavigationHelper
  def primary_navigation_current?(item)
    case item.to_sym
    when :dashboard
      controller_name == "dashboard"
    when :directory
      controller_path.start_with?("directory/") && !%w[clients suppliers].include?(controller_name)
    when :clients
      controller_path == "directory/clients"
    when :suppliers
      controller_path == "directory/suppliers"
    when :departures
      %w[departures travel_programs].include?(controller_name)
    when :administration
      controller_path.start_with?("administration/")
    else
      false
    end
  end

  def primary_nav_current_for(item)
    "page" if primary_navigation_current?(item)
  end
end
