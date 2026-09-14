class InviteAgencyUser < AgencyCommand
  def initialize(agency:, actor:, email_address:, first_name:, last_name:, access_role:, default_office: nil, relationship: nil)
    @agency = agency
    @actor = actor
    @email_address = email_address
    @first_name = first_name
    @last_name = last_name
    @access_role = access_role
    @default_office = default_office
    @relationship = relationship
  end

  def call
    raw_token = nil
    user = nil
    ActiveRecord::Base.transaction do
      @agency.with_lock do
        ensure_permitted!(@actor, :manage_agency_users)
        ensure_active_agency!(@agency)
        ensure_office!
        user = @agency.agency_users.new(
          email_address: @email_address,
          first_name: @first_name,
          last_name: @last_name,
          access_role: @access_role,
          status: "invited",
          default_office: @default_office,
          relationship: @relationship
        )
        raw_token = user.issue_invitation_token
        user.save!
        audit!(agency: @agency, action: "agency_user.invited", subject: user, actor: @actor, details: { "agency_user_id" => user.id, "access_role" => user.access_role })
      end
    end
    InvitationsMailer.invite(user, raw_token).deliver_later
    Result.new(status: :accepted, record: user)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
    raise Error.new(invitation_message(error), code: :invalid)
  end

  private

  def ensure_office!
    return if @default_office.nil?
    return if @default_office.agency_id == @agency.id

    raise Error.new("Choose an office in this agency.", code: :invalid)
  end

  def invitation_message(error)
    return "That email address is already used in this agency." if error.is_a?(ActiveRecord::RecordNotUnique) || error.record.errors.of_kind?(:email_address, :taken)

    error.record.errors.full_messages.to_sentence
  end
end
