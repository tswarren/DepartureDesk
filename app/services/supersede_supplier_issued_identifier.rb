# frozen_string_literal: true

require "ostruct"

# Appends an immutable replacement identifier. The prior row is stamped superseded by
# a database trigger when the successor insert commits; application code never UPDATEs it.
class SupersedeSupplierIssuedIdentifier < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, identifier:, attributes:, confirmation:, idempotency_key:)
    @agency = agency
    @actor = actor
    @identifier = identifier
    @attributes = attributes.to_h.with_indifferent_access
    @confirmation = confirmation
    @idempotency_key = idempotency_key
  end

  def call
    ensure_arrangement_actor!
    key = normalize_idempotency_key(@idempotency_key)

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      prior = SupplierIssuedIdentifier.lock.find_by!(id: @identifier.id, agency_id: @agency.id)
      arrangement = lock_arrangement_for!(prior.supplier_arrangement_id)
      lock_departure_for!(arrangement.departure_id)
      confirmation = SupplierConfirmation.lock.find_by!(id: @confirmation.id, agency_id: @agency.id)

      type = @attributes[:identifier_type].to_s.strip.presence || prior.identifier_type
      unless SupplierIssuedIdentifier::IDENTIFIER_TYPES.include?(type)
        raise Error.new("Choose a valid Supplier identifier type.", code: :invalid)
      end
      display = @attributes[:display_value].to_s.strip
      issuer = @attributes[:issuer_context].to_s.strip.presence || prior.issuer_context
      other_label = @attributes[:other_type_label].to_s.strip.presence
      other_label = prior.other_type_label if type == "other" && other_label.blank?
      if display.blank? || issuer.blank? || ((type == "other") != other_label.present?)
        raise Error.new("Enter a complete qualified Supplier identifier.", code: :invalid)
      end
      normalized = display.downcase

      payload = {
        prior_id: prior.id,
        confirmation_id: confirmation.id,
        identifier_type: type,
        issuer_context: issuer,
        display_value: display,
        other_type_label: other_label
      }
      if (replay = replay_idempotency(key, payload))
        return replay
      end

      raise Error.new("That identifier is already superseded.", code: :invalid_state) if already_superseded?(prior)
      ensure_confirmation_compatible!(confirmation, prior, arrangement)

      acknowledge_cross_owner_duplicates!(
        prior: prior,
        type: type,
        issuer: issuer,
        normalized: normalized
      )

      replacement = SupplierIssuedIdentifier.create!(
        agency: @agency,
        departure_id: prior.departure_id,
        supplier_arrangement_id: prior.supplier_arrangement_id,
        supplier_reservation_id: prior.supplier_reservation_id,
        supplier_id: prior.supplier_id,
        issuer_context: issuer,
        identifier_type: type,
        other_type_label: other_label,
        display_value: display,
        normalized_value: normalized,
        first_supplier_confirmation: confirmation,
        supersedes_id: prior.id
      )
      claim_idempotency!(key, payload, replacement)
      audit!(
        agency: @agency,
        action: "supplier_arrangement.identifier_superseded",
        subject: arrangement,
        actor: @actor,
        details: {
          "supplier_issued_identifier_id" => replacement.id,
          "supersedes_id" => prior.id,
          "supplier_confirmation_id" => confirmation.id
        }
      )
      Result.new(status: :created, record: replacement)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def already_superseded?(prior)
    prior.superseded_at.present? ||
      SupplierIssuedIdentifier.exists?(agency_id: @agency.id, supersedes_id: prior.id)
  end

  def ensure_confirmation_compatible!(confirmation, prior, arrangement)
    unless confirmation.supplier_arrangement_id == arrangement.id &&
        confirmation.confirming_supplier_id == prior.supplier_id
      raise Error.new("That confirmation is not compatible with this identifier.", code: :invalid)
    end
    unless confirmation.supplier_arrangement_version.supplier_arrangement_id == arrangement.id
      raise Error.new("That confirmation belongs to a different Arrangement version.", code: :invalid)
    end

    linked = SupplierConfirmationIdentifierLink.exists?(
      supplier_issued_identifier_id: prior.id,
      supplier_confirmation_id: confirmation.id
    )
    same_version_as_first = confirmation.supplier_arrangement_version_id ==
      prior.first_supplier_confirmation.supplier_arrangement_version_id
    governing_ok = arrangement.governing_version_id.present? &&
      confirmation.supplier_arrangement_version_id == arrangement.governing_version_id
    unless linked || same_version_as_first || governing_ok
      raise Error.new(
        "Choose confirmation evidence from the identifier's exact version or the current governing version.",
        code: :invalid
      )
    end
  end

  def acknowledge_cross_owner_duplicates!(prior:, type:, issuer:, normalized:)
    candidate_scope = SupplierIssuedIdentifier.where(agency_id: @agency.id).where(
      supplier_id: prior.supplier_id,
      identifier_type: type,
      issuer_context: issuer,
      normalized_value: normalized,
      superseded_at: nil
    ).where.not(id: prior.id)
    foreign_rows = if prior.supplier_reservation_id.present?
      candidate_scope.where.not(supplier_reservation_id: [ nil, prior.supplier_reservation_id ])
        .or(candidate_scope.where(supplier_reservation_id: nil))
        .to_a
    else
      candidate_scope.where.not(supplier_arrangement_id: prior.supplier_arrangement_id).to_a
    end
    return if foreign_rows.empty?

    fingerprint = DuplicateAcknowledgement.fingerprint(
      supplier_id: prior.supplier_id,
      identifier_type: type,
      issuer_context: issuer,
      normalized_value: normalized
    )
    candidates = foreign_rows.map do |row|
      OpenStruct.new(id: row.id, signals: [ "supplier_issued_identifier", row.display_value ])
    end
    candidate_digest = DuplicateAcknowledgement.candidate_digest(candidates)
    token = @attributes[:duplicate_acknowledgement_token].presence
    if token.blank?
      raise DuplicateReviewRequired.new(
        token: DuplicateAcknowledgement.issue(
          "shape" => "create",
          "command" => "supplier_issued_identifier.supersede",
          "agency_id" => @agency.id,
          "actor_id" => @actor.id,
          "fingerprint" => fingerprint,
          "candidate_digest" => candidate_digest
        ),
        candidates: candidates
      )
    end
    payload = DuplicateAcknowledgement.verify!(
      token, agency: @agency, actor: @actor, command: "supplier_issued_identifier.supersede"
    )
    unless payload["fingerprint"] == fingerprint
      raise Error.new("That acknowledgement does not match this identifier.", code: :conflict)
    end
    unless payload["candidate_digest"] == candidate_digest
      raise Error.new("Duplicate candidates changed. Review them again.", code: :conflict)
    end
    if DuplicateAcknowledgement.expired?(payload)
      raise Error.new("That acknowledgement has expired.", code: :invalid)
    end
  end

  def replay_idempotency(key, payload)
    lock_idempotency_slot!(self.class.name, key)
    existing = @agency.agency_command_idempotency_keys.where(
      command_name: self.class.name, idempotency_key: key
    ).lock.first
    return unless existing
    unless existing.payload_digest == payload_digest(payload)
      raise Error.new("That idempotency key was already used for different input.", code: :conflict)
    end

    Result.new(status: :replayed, record: SupplierIssuedIdentifier.find(existing.result_record_id))
  end

  def claim_idempotency!(key, payload, record)
    AgencyCommandIdempotencyKey.create!(
      agency: @agency,
      command_name: self.class.name,
      idempotency_key: key,
      payload_digest: payload_digest(payload),
      result_record_type: record.class.name,
      result_record_id: record.id
    )
  end
end
