# Invites an agency user. An Agency Admin invites staff; a reseller user is
# invited to one active relationship by an Agency Admin or staff with
# Reseller relationships (ACC-13; step 9 plan, question 3).
class InviteAgencyUser < AgencyCommand
  def initialize(agency:, actor:, email_address:, first_name:, last_name:, user_type:, default_office: nil, relationship: nil, reseller: nil)
    @agency = agency
    @actor = actor
    @email_address = email_address
    @first_name = first_name
    @last_name = last_name
    @user_type = user_type
    @default_office = default_office
    @relationship = relationship
    @reseller = reseller
  end

  def call
    raw_token = nil
    user = nil
    ActiveRecord::Base.transaction do
      @agency.with_lock do
        ensure_permitted!(@actor, @user_type == "reseller" ? :manage_reseller_relationships : :manage_agency_users)
        ensure_active_agency!(@agency)
        ensure_office!
        ensure_invitable_user_type!
        reseller = invited_reseller
        user = @agency.agency_users.new(
          email_address: @email_address,
          first_name: @first_name,
          last_name: @last_name,
          user_type: @user_type,
          status: "invited",
          default_office: (@default_office unless reseller),
          relationship: @relationship,
          reseller:
        )
        raw_token = user.issue_invitation_token
        user.save!
        audit!(agency: @agency, action: "agency_user.invited", subject: user, actor: @actor,
          details: { "agency_user_id" => user.id, "user_type" => user.user_type, "reseller_id" => user.reseller_id }.compact)
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

  def ensure_invitable_user_type!
    return if @user_type.in?(AgencyUser::USER_TYPES)

    raise Error.new("Choose Agency Admin or Staff.", code: :invalid)
  end

  def invited_reseller
    return if @user_type != "reseller"

    reseller = @reseller && @agency.resellers.lock.find(@reseller.id)
    raise Error.new("Choose a reseller relationship.", code: :invalid) if reseller.nil?
    raise Error.new("#{reseller.name} isn't active, so it can't have new users.", code: :invalid_state) unless reseller.active?

    reseller
  end

  def invitation_message(error)
    return "That email address is already used in this agency." if error.is_a?(ActiveRecord::RecordNotUnique) || error.record.errors.of_kind?(:email_address, :taken)

    error.record.errors.full_messages.to_sentence
  end
end
