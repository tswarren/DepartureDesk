# The action catalog (ADR 0017). Each action has one requirement: :baseline
# (every agency_admin and staff user), :admin_only, one permission, an array of
# permissions (any of them), or :reseller. An agency_admin holds every
# permission implicitly. A reseller satisfies only :reseller. An action not in
# the catalog raises KeyError, so it is refused and a misspelling is loud.
module AccessPermission
  PERMISSIONS = %w[
    departure_management
    supplier_arrangements
    financial_records
    passport_access
    reseller_relationships
  ].freeze

  CATALOG = {
    view_workspace: :baseline,
    select_office_context: :baseline,
    manage_agency_profile: :admin_only,
    manage_offices: :admin_only,
    manage_agency_users: :admin_only,
    manage_user_permissions: :admin_only,
    view_client_directory: :baseline,
    view_client_contact_details: :baseline,
    manage_client_directory: :baseline,
    view_supplier_directory: :baseline,
    view_supplier_contact_details: :baseline,
    manage_supplier_directory: :baseline,
    view_departures: :baseline,
    manage_departures: "departure_management",
    view_arrangements: :baseline,
    manage_arrangements: "supplier_arrangements",
    # ACC-31: supplier cost and commission, including the rate table and
    # supplier documents.
    view_supplier_costs: %w[departure_management supplier_arrangements financial_records],
    # ACC-30: staff use tasks; reassigning one is Departure work.
    use_tasks: :baseline,
    reassign_tasks: "departure_management",
    # SMN-05: a supplier obligation recorded directly as an amount due.
    record_amounts_due: %w[supplier_arrangements financial_records]
  }.freeze

  def self.allowed?(user_type, granted_permissions, action)
    requirement = CATALOG.fetch(action.to_sym)
    user_type = user_type.to_s
    return user_type == "reseller" if requirement == :reseller
    return false unless user_type.in?(%w[agency_admin staff])
    return true if user_type == "agency_admin"

    case requirement
    when :baseline then true
    when :admin_only then false
    else (Array(requirement) & Array(granted_permissions)).any?
    end
  end
end
