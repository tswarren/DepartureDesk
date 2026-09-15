module AccessPermission
  CATALOG = {
    view_workspace: %w[administrator staff viewer],
    select_office_context: %w[administrator staff viewer],
    manage_agency_profile: %w[administrator],
    manage_offices: %w[administrator],
    manage_agency_users: %w[administrator],
    view_client_directory: %w[administrator staff viewer],
    view_client_contact_details: %w[administrator staff],
    manage_client_directory: %w[administrator staff],
    view_supplier_directory: %w[administrator staff viewer],
    view_supplier_contact_details: %w[administrator staff],
    manage_supplier_directory: %w[administrator staff]
  }.freeze

  def self.allowed?(role, permission)
    CATALOG.fetch(permission.to_sym).include?(role.to_s)
  end
end
