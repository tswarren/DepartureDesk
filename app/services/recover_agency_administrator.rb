class RecoverAgencyAdministrator
  class Error < StandardError
    attr_reader :code

    def initialize(message, code: :invalid)
      super(message)
      @code = code
    end
  end

  def initialize(agency:, actor_identifier:, reason:, mode:, membership: nil, email: nil,
    first_name: nil, last_name: nil, preferred_name: nil)
    @agency = agency
    @actor_identifier = actor_identifier
    @reason = reason.to_s.strip
    @mode = mode.to_s
    @membership = membership
    @email = email
    @first_name = first_name
    @last_name = last_name
    @preferred_name = preferred_name
  end

  def call
    raise Error.new("A reason is required.", code: :invalid) if @reason.blank?
    raise Error.new("Operator identifier is required.", code: :invalid) if @actor_identifier.blank?
    raise Error.new("The agency must be active to recover an administrator.", code: :invalid_state) unless @agency.active?

    result = case @mode
    when "reactivate"
      before_reactivate
      reactivate!
    when "replace_invitation", "invite_replacement"
      recover_with_agency_lock
    else
      raise Error.new("Unknown recovery mode.", code: :invalid)
    end

    result
  rescue MembershipCommand::Error => error
    raise Error.new(error.message, code: error.code)
  end

  private

  def recover_with_agency_lock
    result = nil

    ActiveRecord::Base.transaction do
      @agency.with_lock do
        ensure_agency_active!
        record_recovery_started!
        result = case @mode
        when "replace_invitation"
          replace_invitation!
        when "invite_replacement"
          invite_replacement!
        end
      end
    end

    result
  end

  def ensure_agency_active!
    unless @agency.reload.active?
      raise Error.new("The agency must be active to recover an administrator.", code: :invalid_state)
    end
  end

  def record_recovery_started!(agency = @agency)
    RecordAdministrativeAudit.record(
      agency: agency,
      action: "team.administrator_recovery_started",
      actor_identifier: @actor_identifier,
      subject: agency,
      details: { "reason" => @reason, "mode" => @mode }
    )
  end

  def replace_invitation!
    membership = locked_target
    unless membership.administrator? && (membership.invited? || membership.revoked?)
      raise Error.new("That membership cannot receive a replacement invitation.", code: :invalid_state)
    end

    ensure_recovery_default!(membership)

    ReplaceInvitation.new(
      agency: @agency,
      actor_identifier: @actor_identifier,
      privileged: true,
      membership: membership
    ).call
  end

  def reactivate!
    membership = unlocked_target
    unless membership.administrator? && membership.suspended?
      raise Error.new("That membership cannot be reactivated.", code: :invalid_state)
    end

    ReactivateMembership.new(
      agency: @agency,
      actor_identifier: @actor_identifier,
      privileged: true,
      membership: membership,
      after_lock: ->(agency:, membership:, **) {
        record_recovery_started!(agency)
        ensure_recovery_default!(membership)
      }
    ).call
  end

  def invite_replacement!
    raise Error.new("An email is required.", code: :invalid) if @email.blank?
    raise Error.new("A first and last name are required.", code: :invalid) if @first_name.blank? || @last_name.blank?

    default_office = @agency.offices.active.order(:created_at).first
    result = InviteTeamMember.new(
      agency: @agency,
      actor_identifier: @actor_identifier,
      privileged: true,
      email: @email,
      role: "administrator",
      first_name: @first_name,
      last_name: @last_name,
      preferred_name: @preferred_name,
      office_ids: Array(default_office&.id),
      default_office_id: default_office&.id
    ).call

    unless result.enqueue_mail?
      raise Error.new("The replacement administrator cannot be invited.", code: :conflict)
    end

    result
  end

  def locked_target
    membership = unlocked_target
    membership.lock!
    membership
  end

  def unlocked_target
    raise Error.new("A target membership is required.", code: :invalid) unless @membership
    raise Error.new("That membership is not part of this agency.", code: :invalid) unless @membership.agency_id == @agency.id

    @membership
  end

  def ensure_recovery_default!(membership)
    office = @agency.offices.active.order(:created_at).first
    return unless office
    return if membership.has_active_default_office?

    GrantOfficeAccess.new(
      agency: @agency,
      membership: membership,
      office: office,
      make_default: true,
      actor_identifier: @actor_identifier,
      privileged: true
    ).call
  end

  def before_reactivate
  end
end
