class ProvisionAgency
  class Error < StandardError
    attr_reader :code

    def initialize(message, code: :invalid)
      super(message)
      @code = code
    end
  end

  Result = Struct.new(:agency, :membership, :reused, keyword_init: true)

  def initialize(idempotency_key:, actor_identifier:, name:, email:, first_name:, last_name:,
    legal_name: nil, country_code: "US", default_timezone: "UTC", default_currency: "USD",
    preferred_name: nil)
    @idempotency_key = idempotency_key.to_s
    @actor_identifier = actor_identifier.to_s.strip
    @attrs = {
      "name" => name.to_s.strip,
      "legal_name" => legal_name.to_s.strip.presence,
      "country_code" => country_code.to_s.strip.upcase,
      "default_timezone" => default_timezone.to_s.strip,
      "default_currency" => default_currency.to_s.strip.upcase,
      "email" => email.to_s.strip.downcase,
      "first_name" => first_name.to_s.strip,
      "last_name" => last_name.to_s.strip,
      "preferred_name" => preferred_name.to_s.strip.presence
    }
  end

  def call
    validate_required_inputs!

    key_digest = digest(@idempotency_key)
    intent = intent_digest

    if (existing = AgencyProvisioningRequest.find_by(idempotency_key_digest: key_digest))
      return reuse_or_conflict!(existing, intent)
    end

    if AgencyProvisioningRequest.exists?(intent_digest: intent)
      raise Error.new("This provisioning input was already used with a different key.", code: :idempotency_conflict)
    end

    result = persist!(key_digest, intent)

    result
  rescue ActiveRecord::RecordNotUnique
    existing = AgencyProvisioningRequest.find_by(idempotency_key_digest: key_digest)
    return reuse_or_conflict!(existing, intent) if existing

    raise Error.new("This provisioning input was already used with a different key.", code: :idempotency_conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def validate_required_inputs!
    raise Error.new("Idempotency key is required.", code: :invalid) if @idempotency_key.blank?
    raise Error.new("Operator identifier is required.", code: :invalid) if @actor_identifier.blank?
    raise Error.new("Agency name is required.", code: :invalid) if @attrs["name"].blank?
    raise Error.new("Administrator email is required.", code: :invalid) if @attrs["email"].blank?
    raise Error.new("A first and last name are required.", code: :invalid) if @attrs["first_name"].blank? || @attrs["last_name"].blank?
  end

  def persist!(key_digest, intent)
    result = nil

    ActiveRecord::Base.transaction do
      if (user = User.find_by(email_address: @attrs["email"])) && user.active_agency_memberships.exists?
        raise Error.new("The initial administrator cannot be provisioned.", code: :conflict)
      end

      agency = Agency.create!(
        name: @attrs["name"],
        legal_name: @attrs["legal_name"],
        country_code: @attrs["country_code"],
        default_timezone: @attrs["default_timezone"],
        default_currency: @attrs["default_currency"],
        status: "active"
      )

      office = CreateOffice.new(
        agency: agency,
        name: agency.name,
        code: Office.next_main_code(agency),
        actor_identifier: @actor_identifier,
        privileged: true
      ).call.office

      user ||= create_invited_user
      membership = agency.agency_memberships.create!(
        user: user,
        role: "administrator",
        status: "invited",
        invitation_sent_at: Time.current
      )
      GrantOfficeAccess.new(
        agency: agency,
        membership: membership,
        office: office,
        make_default: true,
        actor_identifier: @actor_identifier,
        privileged: true
      ).call

      AgencyProvisioningRequest.create!(
        idempotency_key_digest: key_digest,
        intent_digest: intent,
        agency: agency,
        created_at: Time.current
      )

      RecordAdministrativeAudit.record(
        agency: agency,
        action: "agency.provisioned",
        actor_identifier: @actor_identifier,
        subject: agency,
        details: { "reason" => "provisioned" }
      )
      RecordAdministrativeAudit.record(
        agency: agency,
        action: "team.invitation_created",
        actor_identifier: @actor_identifier,
        subject: membership,
        details: { "membership_id" => membership.id, "user_id" => user.id, "role" => "administrator" }
      )

      DeliveryIntent.record!(
        agency: agency,
        subject: membership,
        purpose: "team_invitation",
        version: membership.invitation_version
      )

      result = Result.new(agency: agency, membership: membership, reused: false)
    end

    result
  end

  def reuse_or_conflict!(existing, intent)
    if existing.intent_digest == intent
      return Result.new(
        agency: existing.agency,
        membership: existing.agency.agency_memberships.administrator.order(:created_at).first,
        reused: true
      )
    end

    raise Error.new("This provisioning key was already used with different inputs.", code: :idempotency_conflict)
  end

  def create_invited_user
    generated_password = SecureRandom.hex(32)
    User.create!(
      email_address: @attrs["email"],
      first_name: @attrs["first_name"],
      last_name: @attrs["last_name"],
      preferred_name: @attrs["preferred_name"],
      password: generated_password,
      password_confirmation: generated_password
    )
  end

  def digest(value)
    Digest::SHA256.hexdigest(value)
  end

  def intent_digest
    digest(@attrs.sort.to_h.to_json)
  end
end
