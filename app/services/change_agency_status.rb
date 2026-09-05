class ChangeAgencyStatus
  class Error < StandardError
    attr_reader :code

    def initialize(message, code: :invalid)
      super(message)
      @code = code
    end
  end

  ALLOWED = {
    "active" => %w[suspended closed],
    "suspended" => %w[active closed],
    "closed" => []
  }.freeze

  ACTIONS = {
    "suspended" => "agency.suspended",
    "active" => "agency.reactivated",
    "closed" => "agency.closed"
  }.freeze

  def initialize(agency:, to:, reason:, actor_identifier:)
    @agency = agency
    @to = to.to_s
    @reason = reason.to_s.strip
    @actor_identifier = actor_identifier
  end

  def call
    raise Error.new("A reason is required.", code: :invalid) if @reason.blank?
    raise Error.new("Operator identifier is required.", code: :invalid) if @actor_identifier.blank?

    affected_user_ids = []

    ActiveRecord::Base.transaction do
      @agency.with_lock do
        unless ALLOWED.fetch(@agency.status, []).include?(@to)
          raise Error.new("That status change is not allowed.", code: :invalid_state)
        end

        if %w[suspended closed].include?(@to)
          affected_user_ids = @agency.agency_memberships.active.pluck(:user_id)
        end

        previous = @agency.status
        @agency.update!(status: @to)
        RecordAdministrativeAudit.record(
          agency: @agency,
          action: ACTIONS[@to],
          actor_identifier: @actor_identifier,
          subject: @agency,
          details: {
            "reason" => @reason,
            "previous_status" => previous,
            "status" => @to
          }
        )
      end
    end

    Session.where(user_id: affected_user_ids).delete_all if affected_user_ids.any?
    @agency.reload
  end
end
