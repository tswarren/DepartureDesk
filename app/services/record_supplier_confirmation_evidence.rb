# frozen_string_literal: true

require "ostruct"

# Builds a SupplierConfirmation and, when supplied, its Supplier identifier link.
# Activation and Hotel confirmation both use this construction.
class RecordSupplierConfirmationEvidence < AgencyCommand
  def initialize(agency:, actor:, arrangement:, version:, recorded_at:,
    evidence_attributes:, identifier_attributes: nil, duplicate_acknowledgement_token: nil,
    evidence_policy: :strict)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @version = version
    @recorded_at = recorded_at
    @evidence_attributes = evidence_attributes.to_h.with_indifferent_access
    identifier_input = identifier_attributes&.to_h&.with_indifferent_access
    @identifier_attributes = identifier_input if identifier_input&.values&.any?(&:present?)
    @duplicate_acknowledgement_token = duplicate_acknowledgement_token
    @evidence_policy = evidence_policy
    return if %i[strict cruise_activation].include?(@evidence_policy)

    raise ArgumentError, "Unknown confirmation evidence policy."
  end

  def call
    attrs = normalized_confirmation_attributes
    confirmation = SupplierConfirmation.create!(
      owner_attributes.merge(
        confirming_supplier_id: @arrangement.contracting_supplier_id,
        actor: @actor,
        recorded_at: @recorded_at,
        **attrs
      )
    )
    ensure_confirmation_compatible!(confirmation)
    identifier = resolve_identifier!(confirmation)
    if identifier
      SupplierConfirmationIdentifierLink.find_or_create_by!(
        owner_attributes.merge(supplier_confirmation: confirmation, supplier_issued_identifier: identifier)
      )
    end
    Result.new(status: :created, record: confirmation)
  end

  private

  def normalized_confirmation_attributes
    kind = @evidence_attributes[:evidence_kind].to_s.strip
    unless SupplierConfirmation::BOOKING_EVIDENCE_KINDS.include?(kind)
      raise Error.new("Choose valid Supplier confirmation evidence.", code: :invalid)
    end
    other_label = @evidence_attributes[:other_evidence_label].to_s.strip.presence
    if (kind == "other") != other_label.present?
      raise Error.new("Enter an other evidence label only for other evidence.", code: :invalid)
    end
    evidence_on = parse_date(@evidence_attributes[:evidence_on], "Evidence date")
    channel = @evidence_attributes[:channel].to_s.strip.presence
    note = @evidence_attributes[:reference_note].to_s.strip.presence
    reason = @evidence_attributes[:confirmed_without_identifier_reason].to_s.strip.presence
    if @evidence_policy != :cruise_activation
      if evidence_on.blank? || channel.blank? || note.blank?
        raise Error.new("Enter complete Supplier confirmation evidence.", code: :invalid)
      end
      if @identifier_attributes.blank? && reason.blank?
        raise Error.new(
          "Enter a Supplier identifier or explain why this is confirmed without one.", code: :invalid
        )
      end
    end
    {
      evidence_kind: kind, other_evidence_label: other_label, evidence_on: evidence_on,
      channel: channel, reference_note: note,
      confirmed_without_identifier_reason: reason
    }
  end

  def ensure_confirmation_compatible!(confirmation)
    compatible = confirmation.agency_id == @agency.id &&
      confirmation.departure_id == @arrangement.departure_id &&
      confirmation.supplier_arrangement_id == @arrangement.id &&
      confirmation.supplier_arrangement_version_id == @version.id &&
      confirmation.confirming_supplier_id == @arrangement.contracting_supplier_id
    unless compatible
      raise Error.new("That confirmation is not compatible with this exact version.", code: :invalid)
    end
  end

  def resolve_identifier!(confirmation)
    return if @identifier_attributes.blank?

    type = @identifier_attributes[:identifier_type].to_s.strip
    unless SupplierIssuedIdentifier::IDENTIFIER_TYPES.include?(type)
      raise Error.new("Choose a valid Supplier identifier type.", code: :invalid)
    end
    display = @identifier_attributes[:display_value].to_s.strip
    normalized = display.downcase
    issuer = @identifier_attributes[:issuer_context].to_s.strip
    other_label = @identifier_attributes[:other_type_label].to_s.strip.presence
    if display.blank?
      raise Error.new("Enter the Supplier identifier.", code: :invalid)
    end
    if issuer.blank?
      raise Error.new("Enter the issuer context for this Supplier identifier.", code: :invalid)
    end
    if (type == "other") != other_label.present?
      message = if type == "other"
        "Enter the other identifier label."
      else
        "Remove the other identifier label unless the type is other."
      end
      raise Error.new(message, code: :invalid)
    end
    lookup = SupplierIssuedIdentifierOwnerLookup.call(
      agency: @agency,
      supplier_id: @arrangement.contracting_supplier_id,
      identifier_type: type,
      issuer_context: issuer,
      normalized_value: normalized,
      arrangement: @arrangement,
      reservation: nil
    )
    if lookup.foreign.any?
      fingerprint = DuplicateAcknowledgement.fingerprint(
        supplier_id: @arrangement.contracting_supplier_id,
        identifier_type: type,
        issuer_context: issuer,
        normalized_value: normalized
      )
      candidates = lookup.foreign.map do |row|
        OpenStruct.new(id: row.id, signals: [ "supplier_issued_identifier", row.display_value ])
      end
      candidate_digest = DuplicateAcknowledgement.candidate_digest(candidates)
      if @duplicate_acknowledgement_token.blank?
        raise DuplicateReviewRequired.new(
          token: DuplicateAcknowledgement.issue(
            "shape" => "create",
            "command" => "supplier_issued_identifier.create",
            "agency_id" => @agency.id,
            "actor_id" => @actor.id,
            "fingerprint" => fingerprint,
            "candidate_digest" => candidate_digest
          ),
          candidates: candidates
        )
      end
      payload = DuplicateAcknowledgement.verify!(
        @duplicate_acknowledgement_token,
        agency: @agency, actor: @actor, command: "supplier_issued_identifier.create"
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
    lookup.same_owner.first ||
      SupplierIssuedIdentifier.create!(
        agency: @agency, departure_id: @arrangement.departure_id,
        supplier_arrangement: @arrangement,
        supplier_id: @arrangement.contracting_supplier_id,
        issuer_context: issuer, identifier_type: type,
        other_type_label: other_label, display_value: display,
        normalized_value: normalized, first_supplier_confirmation: confirmation
      )
  end

  def owner_attributes
    {
      agency: @agency, departure_id: @arrangement.departure_id,
      supplier_arrangement: @arrangement, supplier_arrangement_version: @version
    }
  end

  def parse_date(value, label)
    text = value.to_s.strip
    return if text.blank?

    Date.iso8601(text)
  rescue ArgumentError
    raise Error.new("Enter a valid #{label.downcase}.", code: :invalid)
  end
end
