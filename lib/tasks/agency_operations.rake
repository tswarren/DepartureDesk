module AgencyOperationsTask
  module_function

  def required_env(name)
    ENV.fetch(name) { abort("#{name} is required") }
  end
end

namespace :agency do
  desc "Provision a new agency, first office, and first administrator"
  task provision: :environment do
    result = ProvisionAgency.new(
      name: AgencyOperationsTask.required_env("AGENCY_NAME"),
      workspace_code: AgencyOperationsTask.required_env("AGENCY_WORKSPACE_CODE"),
      country_code: ENV.fetch("AGENCY_COUNTRY_CODE", "US"),
      default_currency: ENV.fetch("AGENCY_CURRENCY", "USD"),
      default_timezone: ENV.fetch("AGENCY_TIMEZONE", "UTC"),
      office_name: ENV.fetch("AGENCY_OFFICE_NAME", AgencyOperationsTask.required_env("AGENCY_NAME")),
      office_code: ENV.fetch("AGENCY_OFFICE_CODE", "MAIN"),
      office_timezone: ENV.fetch("AGENCY_OFFICE_TIMEZONE", ENV.fetch("AGENCY_TIMEZONE", "UTC")),
      administrator_email: AgencyOperationsTask.required_env("AGENCY_ADMIN_EMAIL"),
      administrator_first_name: AgencyOperationsTask.required_env("AGENCY_ADMIN_FIRST_NAME"),
      administrator_last_name: AgencyOperationsTask.required_env("AGENCY_ADMIN_LAST_NAME"),
      administrator_password: AgencyOperationsTask.required_env("AGENCY_ADMIN_PASSWORD"),
      actor_identifier: AgencyOperationsTask.required_env("AGENCY_OPERATOR")
    ).call

    agency = result.record
    puts "Agency ID: #{agency.id}"
    puts "Workspace code: #{agency.workspace_code}"
    puts "Office ID: #{agency.offices.order(:created_at).first.id}"
    puts "Administrator ID: #{agency.agency_users.order(:created_at).first.id}"
  end

  desc "Change an agency lifecycle status"
  task change_status: :environment do
    agency = Agency.find(AgencyOperationsTask.required_env("AGENCY_ID"))
    ChangeAgencyStatus.new(
      agency: agency,
      status: AgencyOperationsTask.required_env("AGENCY_STATUS"),
      actor_identifier: AgencyOperationsTask.required_env("AGENCY_OPERATOR")
    ).call

    puts "Agency ID: #{agency.id}"
    puts "Status: #{agency.reload.status}"
  end
end
