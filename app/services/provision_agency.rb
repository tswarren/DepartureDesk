class ProvisionAgency < AgencyCommand
  def initialize(name:, workspace_code:, country_code:, default_currency:, default_timezone:, office_name:, office_code:, office_timezone:, administrator_email:, administrator_first_name:, administrator_last_name:, administrator_password:, actor_identifier:)
    @name = name
    @workspace_code = workspace_code
    @country_code = country_code
    @default_currency = default_currency
    @default_timezone = default_timezone
    @office_name = office_name
    @office_code = office_code
    @office_timezone = office_timezone
    @administrator_email = administrator_email
    @administrator_first_name = administrator_first_name
    @administrator_last_name = administrator_last_name
    @administrator_password = administrator_password
    @actor_identifier = actor_identifier
  end

  def call
    raise Error.new("A system actor identifier is required.", code: :invalid) if @actor_identifier.blank?

    ActiveRecord::Base.transaction do
      agency = Agency.create!(
        name: @name,
        workspace_code: @workspace_code,
        country_code: @country_code,
        default_currency: @default_currency,
        default_timezone: @default_timezone,
        status: "active"
      )
      office = agency.offices.create!(
        name: @office_name,
        code: @office_code,
        default_timezone: @office_timezone,
        status: "active"
      )
      agency.reference_sequences.create!(namespace: "client", next_value: 1)
      administrator = agency.agency_users.create!(
        email_address: @administrator_email,
        first_name: @administrator_first_name,
        last_name: @administrator_last_name,
        password: @administrator_password,
        access_role: "administrator",
        status: "active",
        default_office: office,
        credential_version: 1
      )
      audit!(
        agency: agency,
        action: "agency.provisioned",
        subject: agency,
        actor_identifier: @actor_identifier,
        details: {
          "agency_id" => agency.id,
          "workspace_code" => agency.workspace_code,
          "office_id" => office.id,
          "administrator_id" => administrator.id
        }
      )
      Result.new(status: :accepted, record: agency)
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end
end
