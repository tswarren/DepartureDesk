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

  def ensure_active_agency!(agency)
    return if agency&.active?

    raise Error.new("That agency is not active.", code: :invalid_state)
  end

  def ensure_not_last_active_administrator!(agency_user)
    return unless agency_user.role_administrator? && agency_user.active?
    return if other_active_administrators(agency_user).exists?

    raise Error.new("The agency must keep an active administrator.", code: :last_administrator)
  end

  def other_active_administrators(agency_user)
    agency_user.agency.agency_users.where(status: "active", access_role: "administrator").where.not(id: agency_user.id)
  end

  def destroy_sessions!(agency_user)
    agency_user.sessions.destroy_all
  end
end
