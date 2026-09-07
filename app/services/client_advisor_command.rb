class ClientAdvisorCommand < RoleProfileCommand
  private

  def profile_association
    :client_profile
  end

  def role_noun
    "client"
  end

  def ensure_assignable_advisor!(membership)
    unless membership.active?
      raise Error.new("Choose an active team member as advisor.", code: :invalid)
    end
    unless membership.agency_id == @agency.id
      raise Error.new("That team member is not part of this agency.", code: :not_found)
    end
  end

  def end_open_assignment!(profile, reason:)
    assignment = profile.open_advisor_assignment
    return if assignment.nil?

    today = DirectoryDate.today(@agency)
    exclusive_until = assignment.effective_from < today ? today : assignment.effective_from
    assignment.update!(
      effective_until: exclusive_until,
      ended_at: Time.current,
      ended_by_membership: actor_membership!(@agency),
      ending_reason: reason
    )
  end

  def set_current_advisor!(profile, membership)
    profile.update!(
      primary_advisor_membership: membership,
      primary_advisor_membership_status: membership ? "active" : nil
    )
  end

  def audit_advisor!(profile, action, extra = {})
    audit!(
      agency: @agency,
      action:,
      subject: extra.delete(:subject) || profile.open_advisor_assignment || profile,
      details: {
        "party_id" => profile.party_id,
        "client_profile_id" => profile.id,
        "primary_advisor_membership_id" => profile.primary_advisor_membership_id
      }.merge(extra),
      **actor_audit_args
    )
  end
end
