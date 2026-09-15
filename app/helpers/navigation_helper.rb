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
      controller_path == "suppliers" || controller_path.start_with?("supplier_")
    else
      false
    end
  end

  def primary_nav_current_for(item)
    "page" if primary_navigation_current?(item)
  end
end
