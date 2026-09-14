class CreateOffice < AgencyCommand
  def initialize(agency:, actor:, name:, code:, default_timezone:)
    @agency = agency
    @actor = actor
    @name = name
    @code = code
    @default_timezone = default_timezone
  end

  def call
    ActiveRecord::Base.transaction do
      @agency.with_lock do
        ensure_permitted!(@actor, :manage_offices)
        ensure_active_agency!(@agency)
        office = @agency.offices.create!(name: @name, code: @code, default_timezone: @default_timezone, status: "active")
        audit!(agency: @agency, action: "office.created", subject: office, actor: @actor, details: { "office_id" => office.id, "code" => office.code })
        Result.new(status: :accepted, record: office)
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end
end
