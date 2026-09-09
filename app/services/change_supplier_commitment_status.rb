class ChangeSupplierCommitmentStatus < DepartureCommand
  ACTIONS = {
    "released" => "supplier_commitment.released",
    "satisfied" => "supplier_commitment.satisfied",
    "cancelled" => "supplier_commitment.cancelled"
  }.freeze

  def initialize(agency:, commitment:, status:, reason:, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @commitment = commitment
    @departure = commitment.departure
    @status = status.to_s
    @reason = reason.to_s.strip
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    raise Error.new("A status reason is required.", code: :invalid) if @reason.blank?
    raise Error.new("Choose a supported commitment status.", code: :invalid) unless ACTIONS.key?(@status)
    ActiveRecord::Base.transaction do
      with_departure_locks(@agency, offices: [ @commitment.office ], departure: @departure, supplier_arrangements: [ @commitment.arrangement ], supplier_commitments: [ @commitment ]) { perform }
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This supplier commitment was updated by someone else.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def perform
    actor = actor_membership(@agency)
    ensure_office_access!(actor, @commitment.office)
    require_manager_or_administrator!(actor, @departure)
    ensure_fresh_lock!(@commitment, @lock_version)
    return CommandResult.new(status: :accepted, departure: @departure, supplier_commitment: @commitment) if @commitment.status == @status
    raise Error.new("Only open supplier commitments can change status.", code: :invalid_state) unless @commitment.open?

    @commitment.update!(status: @status, status_reason: @reason, status_changed_at: Time.current, status_changed_by_membership: actor)
    audit!(agency: @agency, action: ACTIONS.fetch(@status), subject: @commitment, details: { "supplier_commitment_id" => @commitment.id, "reason" => @reason }, **actor_audit_args)
    CommandResult.new(status: :accepted, departure: @departure, supplier_commitment: @commitment)
  end
end
