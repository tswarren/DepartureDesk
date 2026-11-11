class AgencyCommand
  class Error < StandardError
    attr_reader :code

    def initialize(message, code: :invalid)
      @code = code
      super(message)
    end
  end

  UNAUTHORIZED = "You are not allowed to do that."
  GENERIC_FAILURE = "Try another workspace, email address, or password."

  Result = Data.define(:status, :record)

  class DuplicateReviewRequired < Error
    attr_reader :token, :candidates

    def initialize(token:, candidates:)
      @token = token
      @candidates = candidates
      super("Review possible duplicates before saving.", code: :duplicate_review_required)
    end
  end

  private

  def audit!(agency:, action:, subject:, details: {}, actor: nil, actor_identifier: nil)
    RecordAdministrativeAudit.record(
      agency: agency,
      action: action,
      actor_agency_user: actor,
      actor_identifier: actor_identifier,
      subject: subject,
      details: details
    )
  end

  def ensure_permitted!(actor, permission)
    return if actor&.permitted?(permission)

    raise Error.new(UNAUTHORIZED, code: :unauthorized)
  end

  def ensure_directory_actor!(actor, agency, permission)
    return if actor&.active? && actor.agency_id == agency&.id && actor.permitted?(permission)

    raise Error.new(UNAUTHORIZED, code: :unauthorized)
  end

  def duplicate_override_details(decision, reason:, extra: {})
    candidates = Array(decision.is_a?(Hash) ? decision["reviewed_candidates"] : nil)
    {
      "reason_code" => reason,
      "candidate_ids" => candidates.map { |candidate| candidate["id"] },
      "signals" => candidates.flat_map { |candidate| Array(candidate["signals"]) }.uniq.sort
    }.merge(extra)
  end

  # Step 9 plan, question 8: a reseller user acts only through the commands
  # that accept one, as an active user of an active relationship in the
  # agency. Every other command refuses it through its staff requirement.
  def reseller_actor? = @actor&.reseller?

  def ensure_reseller_actor!(action)
    ensure_directory_actor!(@actor, @agency, action)
    return if @actor.reseller&.active? && @actor.reseller.agency_id == @agency.id

    raise Error.new(UNAUTHORIZED, code: :unauthorized)
  end

  def ensure_active_agency!(agency)
    return if agency&.active?

    raise Error.new("That agency is not active.", code: :invalid_state)
  end

  def ensure_not_last_active_administrator!(agency_user)
    return unless agency_user.agency_admin? && agency_user.active?
    return if other_active_administrators(agency_user).exists?

    raise Error.new("The agency must keep an active administrator.", code: :last_administrator)
  end

  def other_active_administrators(agency_user)
    agency_user.agency.agency_users.where(status: "active", user_type: "agency_admin").where.not(id: agency_user.id)
  end

  # Grants exist only for staff; the database refuses a type change that would
  # leave any behind, so remove them first in the same transaction.
  def assign_user_type!(agency_user, user_type)
    return [] if user_type.blank? || user_type == agency_user.user_type

    removed = []
    if agency_user.staff?
      removed = agency_user.user_permissions.order(:permission).pluck(:permission)
      agency_user.user_permissions.delete_all(:delete_all)
    end
    agency_user.user_type = user_type
    removed
  end

  def destroy_sessions!(agency_user)
    agency_user.sessions.destroy_all
  end
end
