module AgencyOperationsTask
  module_function

  def required_env(name)
    ENV.fetch(name) { abort("#{name} is required") }
  end
end

namespace :agency do
  desc "Provision a new agency and invite its first administrator"
  task provision: :environment do
    result = ProvisionAgency.new(
      idempotency_key: AgencyOperationsTask.required_env("AGENCY_PROVISIONING_KEY"),
      actor_identifier: AgencyOperationsTask.required_env("AGENCY_OPERATOR"),
      name: AgencyOperationsTask.required_env("AGENCY_NAME"),
      legal_name: ENV["AGENCY_LEGAL_NAME"],
      country_code: ENV.fetch("AGENCY_COUNTRY_CODE", "US"),
      default_timezone: ENV.fetch("AGENCY_TIMEZONE", "UTC"),
      default_currency: ENV.fetch("AGENCY_CURRENCY", "USD"),
      email: AgencyOperationsTask.required_env("AGENCY_ADMIN_EMAIL"),
      first_name: AgencyOperationsTask.required_env("AGENCY_ADMIN_FIRST_NAME"),
      last_name: AgencyOperationsTask.required_env("AGENCY_ADMIN_LAST_NAME"),
      preferred_name: ENV["AGENCY_ADMIN_PREFERRED_NAME"]
    ).call

    puts "Agency ID: #{result.agency.id}"
    puts "Agency name: #{result.agency.name}"
    puts "Membership ID: #{result.membership.id}"
    puts "Reused existing provisioning request: #{result.reused}"
    puts "Next: the invited administrator must accept the invitation email."
  end

  desc "Change an agency lifecycle status"
  task change_status: :environment do
    agency = Agency.find(AgencyOperationsTask.required_env("AGENCY_ID"))
    ChangeAgencyStatus.new(
      agency: agency,
      to: AgencyOperationsTask.required_env("AGENCY_STATUS"),
      reason: AgencyOperationsTask.required_env("AGENCY_REASON"),
      actor_identifier: AgencyOperationsTask.required_env("AGENCY_OPERATOR")
    ).call

    puts "Agency ID: #{agency.id}"
    puts "Status: #{agency.reload.status}"
  end

  desc "Recover administrative access for an active agency"
  task recover_administrator: :environment do
    agency = Agency.find(AgencyOperationsTask.required_env("AGENCY_ID"))
    membership_id = ENV["AGENCY_MEMBERSHIP_ID"].presence
    membership = membership_id && AgencyMembership.find(membership_id)
    result = RecoverAgencyAdministrator.new(
      agency: agency,
      actor_identifier: AgencyOperationsTask.required_env("AGENCY_OPERATOR"),
      reason: AgencyOperationsTask.required_env("AGENCY_REASON"),
      mode: AgencyOperationsTask.required_env("AGENCY_RECOVERY_MODE"),
      membership: membership,
      email: ENV["AGENCY_ADMIN_EMAIL"],
      first_name: ENV["AGENCY_ADMIN_FIRST_NAME"],
      last_name: ENV["AGENCY_ADMIN_LAST_NAME"],
      preferred_name: ENV["AGENCY_ADMIN_PREFERRED_NAME"]
    ).call

    puts "Agency ID: #{agency.id}"
    puts "Recovery mode: #{ENV.fetch("AGENCY_RECOVERY_MODE")}"
    puts "Membership ID: #{result.membership&.id}"
    puts "Next: confirm the matching audit events and any invitation email."
  end
end
