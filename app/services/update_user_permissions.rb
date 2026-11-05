# Sets a staff user's permission grants (ADR 0017; ACC-11, ACC-23, ACC-24,
# ACC-33). Only an Agency Admin may call it. One save writes one audit event
# naming the permissions granted and revoked.
class UpdateUserPermissions < AgencyCommand
  def initialize(agency_user:, actor:, permissions:, lock_version:)
    @agency_user = agency_user
    @actor = actor
    @permissions = Array(permissions).compact_blank.map(&:to_s).uniq.sort
    @lock_version = lock_version
  end

  def call
    ActiveRecord::Base.transaction do
      agency = @agency_user.agency
      agency.with_lock do
        @agency_user.lock!
        @agency_user.reload
        ensure_permitted!(@actor, :manage_user_permissions)
        ensure_fresh_lock!
        ensure_permissions_known!
        raise Error.new("Only staff users hold individual permissions.", code: :invalid_state) unless @agency_user.staff?

        current = @agency_user.user_permissions.order(:permission).pluck(:permission)
        granted = @permissions - current
        revoked = current - @permissions
        return Result.new(status: :noop, record: @agency_user) if granted.empty? && revoked.empty?

        @agency_user.user_permissions.where(permission: revoked).delete_all
        granted.each { |permission| @agency_user.user_permissions.create!(agency:, permission:) }
        @agency_user.touch
        audit!(
          agency:,
          action: "agency_user.permissions_changed",
          subject: @agency_user,
          actor: @actor,
          details: {
            "agency_user_id" => @agency_user.id,
            "granted" => granted,
            "revoked" => revoked,
            "permissions" => @permissions
          }
        )
      end
    end
    Result.new(status: :updated, record: @agency_user)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def ensure_fresh_lock!
    return if @lock_version.present? && @agency_user.lock_version == @lock_version.to_i

    raise Error.new("This user was updated by someone else.", code: :conflict)
  end

  def ensure_permissions_known!
    unknown = @permissions - AccessPermission::PERMISSIONS
    return if unknown.empty?

    raise Error.new("That permission is not available.", code: :invalid)
  end
end
