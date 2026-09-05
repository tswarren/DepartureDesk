class CreateOffice < MembershipCommand
  def initialize(agency:, name:, code:, default_timezone: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @name = name
    @code = code
    @default_timezone = default_timezone
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    ActiveRecord::Base.transaction do
      with_agency_office_lock(@agency) { perform }
    end
  rescue ActiveRecord::RecordNotUnique
    raise Error.new("That office code is already used.", code: :conflict)
  end

  private

  def perform
    office = @agency.offices.create!(
      name: @name,
      code: @code,
      status: "active",
      default_timezone: @default_timezone.presence || @agency.default_timezone
    )
    audit!(
      agency: @agency,
      action: "office.created",
      subject: office,
      details: {
        "office_id" => office.id,
        "office_code" => office.code,
        "name" => office.name
      },
      **actor_audit_args
    )
    CommandResult.new(status: :created, office: office)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end
end
