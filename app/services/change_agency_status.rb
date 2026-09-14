class ChangeAgencyStatus < AgencyCommand
  TRANSITIONS = {
    "active" => %w[suspended closed],
    "suspended" => %w[active closed],
    "closed" => []
  }.freeze

  def initialize(agency:, status:, actor_identifier:, lock_version: nil)
    @agency = agency
    @status = status.to_s
    @actor_identifier = actor_identifier
    @lock_version = lock_version
  end

  def call
    raise Error.new("A system actor identifier is required.", code: :invalid) if @actor_identifier.blank?

    ActiveRecord::Base.transaction do
      @agency.with_lock do
        @agency.reload
        raise Error.new("This agency was updated by someone else.", code: :conflict) if stale?
        unless TRANSITIONS.fetch(@agency.status).include?(@status)
          raise Error.new("That agency status change is not allowed.", code: :invalid_state)
        end

        @agency.update!(status: @status)
        Session.joins(:agency_user).where(agency_users: { agency_id: @agency.id }).destroy_all unless @agency.active?
        audit!(
          agency: @agency,
          action: audit_action,
          subject: @agency,
          actor_identifier: @actor_identifier,
          details: { "agency_id" => @agency.id, "status" => @agency.status }
        )
      end
    end
    Result.new(status: :accepted, record: @agency)
  end

  private

  def stale?
    @lock_version.present? && @agency.lock_version != @lock_version.to_i
  end

  def audit_action
    case @status
    when "suspended" then "agency.suspended"
    when "active" then "agency.reactivated"
    when "closed" then "agency.closed"
    end
  end
end
