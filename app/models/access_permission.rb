module AccessPermission
  CATALOG = {
    view_workspace: %w[administrator staff viewer],
    select_office_context: %w[administrator staff viewer],
    manage_agency_profile: %w[administrator],
    manage_offices: %w[administrator],
    manage_agency_users: %w[administrator]
  }.freeze

  def self.allowed?(role, permission)
    CATALOG.fetch(permission.to_sym).include?(role.to_s)
  end
end
