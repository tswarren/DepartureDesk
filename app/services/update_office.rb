class UpdateOffice < MembershipCommand
  def initialize(agency:, office:, name:, default_timezone:, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @office = office
    @name = name
    @default_timezone = default_timezone
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    ActiveRecord::Base.transaction do
      with_agency_office_lock(@agency, office: @office) { perform }
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This office was updated by someone else.", code: :conflict)
  end

  private

  def perform
    if @lock_version && @office.lock_version != @lock_version.to_i
      raise ActiveRecord::StaleObjectError.new(@office, "update")
    end

    before = { "name" => @office.name, "default_timezone" => @office.default_timezone }
    @office.assign_attributes(name: @name, default_timezone: @default_timezone)
    return CommandResult.new(status: :accepted, office: @office) unless @office.changed?

    @office.save!
    after = { "name" => @office.name, "default_timezone" => @office.default_timezone }
    changed = before.keys.select { |field| before[field] != after[field] }
    audit!(
      agency: @agency,
      action: "office.updated",
      subject: @office,
      details: {
        "office_id" => @office.id,
        "office_code" => @office.code,
        "changed_fields" => changed,
        "before" => before.slice(*changed),
        "after" => after.slice(*changed)
      },
      **actor_audit_args
    )
    CommandResult.new(status: :accepted, office: @office)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end
end
