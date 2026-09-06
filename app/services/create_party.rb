class CreateParty < MembershipCommand
  PROFILE_ATTRS = {
    "person" => %i[
      given_name middle_name family_name prefix suffix preferred_name
      form_of_address pronouns date_of_birth
    ],
    "household" => %i[name correspondence_name],
    "organization" => %i[legal_name trading_name website]
  }.freeze

  def initialize(agency:, party_kind:, attributes:, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @party_kind = party_kind.to_s
    @attributes = attributes.to_h.symbolize_keys
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    ActiveRecord::Base.transaction do
      with_operator_lock { perform }
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def with_operator_lock
    ensure_actor_shape!
    @agency.with_lock do
      @agency.reload
      ensure_agency_operator!(@agency)
      yield
    end
  end

  def perform
    unless Party::KINDS.include?(@party_kind)
      raise Error.new("Choose a person, household, or organization.", code: :invalid)
    end

    party = @agency.parties.new(party_kind: @party_kind, status: "active")
    profile = profile_class.new(agency: @agency)
    profile.assign_attributes(permitted_attributes)
    party.apply_derived_names!(profile)
    party.save!
    profile.party = party
    profile.party_id = party.id
    profile.save!

    audit!(
      agency: @agency,
      action: "directory.party_created",
      subject: party,
      details: {
        "party_id" => party.id,
        "party_kind" => party.party_kind
      },
      **actor_audit_args
    )
    CommandResult.new(status: :created, party: party)
  end

  def profile_class
    { "person" => Person, "household" => Household, "organization" => Organization }.fetch(@party_kind)
  end

  def permitted_attributes
    allowed = PROFILE_ATTRS.fetch(@party_kind)
    @attributes.slice(*allowed)
  end
end
