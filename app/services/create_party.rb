class CreateParty < MembershipCommand
  PROFILE_ATTRS = {
    "person" => %i[
      given_name middle_name family_name prefix suffix preferred_name
      form_of_address pronouns date_of_birth
    ],
    "household" => %i[name correspondence_name],
    "organization" => %i[legal_name trading_name website]
  }.freeze

  def initialize(agency:, party_kind:, attributes:, actor: nil, actor_identifier: nil, privileged: false, create_anyway: false, duplicate_override_reason: nil, acknowledged_candidate_ids: [], acknowledged_strength: nil)
    @agency = agency
    @party_kind = party_kind.to_s
    @attributes = attributes.to_h.symbolize_keys
    @create_anyway = ActiveModel::Type::Boolean.new.cast(create_anyway)
    @duplicate_override_reason = duplicate_override_reason.to_s.strip.presence
    @acknowledged_candidate_ids = Array(acknowledged_candidate_ids).map(&:to_s).reject(&:blank?).sort
    @acknowledged_strength = acknowledged_strength.to_s.presence
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

    match = current_match
    lock_match_parties!(match)
    match = current_match

    unless @create_anyway
      unless match.none?
        return CommandResult.new(status: :duplicate_review, duplicate_match: match)
      end
    else
      enforce_acknowledged_match!(match)
      if match.strong? && @duplicate_override_reason.blank?
        raise Error.new("Enter a reason to create a separate identity.", code: :invalid)
      end
    end

    party = @agency.parties.new(party_kind: @party_kind, status: "active")
    profile = profile_class.new(agency: @agency, party_kind: @party_kind)
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
      details: created_audit_details(party, match),
      **actor_audit_args
    )
    CommandResult.new(status: :created, party: party, duplicate_match: match)
  end

  def current_match
    PartyDuplicateMatcher.new(
      agency: @agency,
      party_kind: @party_kind,
      attributes: permitted_attributes
    ).call
  end

  def lock_match_parties!(match)
    parties = @agency.parties.where(id: match.candidate_ids).to_a
    parties.sort_by { |party| party.id.to_s }.each do |party|
      party.lock!
      party.reload
    end
  end

  def enforce_acknowledged_match!(match)
    return if match.none?

    current_ids = match.candidate_ids.map(&:to_s).sort
    if current_ids != @acknowledged_candidate_ids || match.strength != @acknowledged_strength
      raise Error.new("Possible matches changed. Review them again.", code: :stale)
    end
  end

  def created_audit_details(party, match)
    details = {
      "party_id" => party.id,
      "party_kind" => party.party_kind
    }
    return details if !@create_anyway || match.none?

    details["duplicate_override_strength"] = match.strength
    details["duplicate_candidate_ids"] = match.candidate_ids
    details["duplicate_override_reason"] = @duplicate_override_reason if match.strong?
    details
  end

  def profile_class
    { "person" => Person, "household" => Household, "organization" => Organization }.fetch(@party_kind)
  end

  def permitted_attributes
    allowed = PROFILE_ATTRS.fetch(@party_kind)
    @attributes.slice(*allowed)
  end
end
