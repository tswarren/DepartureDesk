class DeactivateClientProfile < DeactivateRoleProfile
  private

  def profile_association
    :client_profile
  end

  def role_noun
    "client"
  end

  def perform
    ensure_profile_on_party!(@party, @profile)
    return profile_result(:accepted, @party, @profile) if @profile.inactive?
    raise Error.new("Enter a reason for deactivation.", code: :invalid) if @reason.blank?

    ensure_fresh_lock!(@profile, @lock_version)
    end_open_assignment_if_present!
    @profile.update!(
      status: "inactive",
      party_status: nil,
      responsible_office_status: nil,
      primary_advisor_membership: nil,
      primary_advisor_membership_status: nil,
      deactivated_at: Time.current,
      deactivated_by_membership: actor_membership!(@agency),
      deactivation_reason: @reason
    )
    audit_profile!(@profile, "directory.client_profile_deactivated")
    profile_result(:accepted, @party, @profile)
  end

  def end_open_assignment_if_present!
    assignment = @profile.open_advisor_assignment
    return if assignment.nil?

    today = DirectoryDate.today(@agency)
    exclusive_until = assignment.effective_from < today ? today : assignment.effective_from
    assignment.update!(
      effective_until: exclusive_until,
      ended_at: Time.current,
      ended_by_membership: actor_membership!(@agency),
      ending_reason: @reason
    )
  end
end
