class ChangeOfficeStatus < AgencyCommand
  def initialize(office:, actor:, status:, lock_version: nil)
    @office = office
    @actor = actor
    @status = status.to_s
    @lock_version = lock_version
  end

  def call
    ActiveRecord::Base.transaction do
      @office.agency.with_lock do
        @office.lock!
        @office.reload
        ensure_permitted!(@actor, :manage_offices)
        raise Error.new("This office was updated by someone else.", code: :conflict) if @lock_version.present? && @office.lock_version != @lock_version.to_i
        unless (%w[active inactive] - [ @office.status ]).include?(@status)
          raise Error.new("That office status change is not allowed.", code: :invalid_state)
        end

        @office.update!(status: @status)
        if @office.inactive?
          AgencyUser.where(default_office_id: @office.id).update_all(default_office_id: nil, updated_at: Time.current)
          Session.where(office_id: @office.id).update_all(office_id: nil, updated_at: Time.current)
        end
        audit!(
          agency: @office.agency,
          action: @office.active? ? "office.reactivated" : "office.deactivated",
          subject: @office,
          actor: @actor,
          details: { "office_id" => @office.id, "status" => @office.status }
        )
      end
    end
    Result.new(status: :accepted, record: @office)
  end
end
