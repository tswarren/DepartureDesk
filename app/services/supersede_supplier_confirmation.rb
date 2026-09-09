class SupersedeSupplierConfirmation < DepartureCommand
  def initialize(agency:, confirmation:, reason:, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @confirmation = confirmation
    @departure = confirmation.departure
    @reason = reason.to_s.strip
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    raise Error.new("A supersession reason is required.", code: :invalid) if @reason.blank?
    ActiveRecord::Base.transaction do
      with_departure_locks(@agency, offices: [ @confirmation.office ], departure: @departure, supplier_confirmations: [ @confirmation ]) { perform }
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This supplier confirmation was updated by someone else.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def perform
    actor = actor_membership(@agency)
    ensure_office_access!(actor, @confirmation.office)
    ensure_fresh_lock!(@confirmation, @lock_version)
    return CommandResult.new(status: :accepted, departure: @departure, supplier_confirmation: @confirmation) if @confirmation.superseded?

    @confirmation.update!(status: "superseded", superseded_at: Time.current, superseded_by_membership: actor, supersession_reason: @reason)
    audit!(agency: @agency, action: "supplier_confirmation.superseded", subject: @confirmation, details: { "supplier_confirmation_id" => @confirmation.id, "reason" => @reason }, **actor_audit_args)
    CommandResult.new(status: :accepted, departure: @departure, supplier_confirmation: @confirmation)
  end
end
