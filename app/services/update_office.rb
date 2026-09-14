class UpdateOffice < AgencyCommand
  def initialize(office:, actor:, name:, default_timezone:, lock_version: nil)
    @office = office
    @actor = actor
    @name = name
    @default_timezone = default_timezone
    @lock_version = lock_version
  end

  def call
    ActiveRecord::Base.transaction do
      @office.agency.with_lock do
        @office.lock!
        @office.reload
        ensure_permitted!(@actor, :manage_offices)
        raise Error.new("This office was updated by someone else.", code: :conflict) if stale?
        @office.update!(name: @name, default_timezone: @default_timezone)
        audit!(agency: @office.agency, action: "office.updated", subject: @office, actor: @actor, details: { "office_id" => @office.id })
      end
    end
    Result.new(status: :accepted, record: @office)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def stale?
    @lock_version.present? && @office.lock_version != @lock_version.to_i
  end
end
