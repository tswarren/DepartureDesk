# frozen_string_literal: true

# Records readable Cruise terms. These terms do not calculate charges or share a policy engine.
class RecordCruiseAgreementTerms < AgencyCommand
  include ArrangementCommandSupport

  COMMAND_NAME = "record_cruise_agreement_terms"

  def initialize(
    agency:, actor:, arrangement:, version_lock_version:, idempotency_key:,
    allocated_cabin_deposit: nil, card_restrictions: nil, cancellation_steps: nil
  )
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @version_lock_version = version_lock_version
    @idempotency_key = idempotency_key
    @allocated_cabin_deposit = allocated_cabin_deposit
    @card_restrictions = card_restrictions
    @cancellation_steps = cancellation_steps
  end

  def call
    ensure_arrangement_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      departure, arrangement, version = lock_departure_arrangement_version!(@arrangement)
      ensure_draft_graph!(arrangement, version)
      ensure_departure_accepts_new_planning!(departure)
      payload = {
        supplier_arrangement_version_id: version.id,
        allocated_cabin_deposit: @allocated_cabin_deposit,
        card_restrictions: @card_restrictions.to_s.strip.presence,
        cancellation_steps: normalized_steps
      }
      if (replay = replay!(payload))
        return replay
      end

      ensure_current_lock_version!(version, @version_lock_version)
      records = []
      records << upsert_allocated!(arrangement, version) if @allocated_cabin_deposit.present?
      records << upsert_card!(arrangement, version) if @card_restrictions.present?
      records.concat(replace_cancellation!(arrangement, version)) if @cancellation_steps.present?
      raise Error.new("Enter a Cruise term to record.", code: :invalid) if records.empty?

      bump_version!(version)
      audit!(
        agency: @agency,
        action: "supplier_arrangement.updated",
        subject: arrangement,
        actor: @actor,
        details: {
          "supplier_arrangement_id" => arrangement.id,
          "supplier_arrangement_version_id" => version.id,
          "changed_fields" => [ "cruise_agreement_terms" ]
        }
      )
      claim!(payload, records.first)
      Result.new(status: :created, record: records.first)
    end
  end

  private

  def upsert_allocated!(arrangement, version)
    attrs = @allocated_cabin_deposit.to_h.with_indifferent_access
    amount = Integer(attrs[:amount_minor_units], exception: false)
    credit = Integer(attrs[:credit_minor_units], exception: false)
    currency = attrs[:currency].to_s.upcase
    body = attrs[:body].to_s.strip
    if amount.nil? || amount <= 0 || credit.nil? || credit.negative? || currency !~ /\A[A-Z]{3}\z/ || body.blank?
      raise Error.new("Enter the allocated-cabin amount, credit, currency, and wording.", code: :invalid)
    end

    upsert_singleton!(arrangement, version, "allocated_cabin_deposit", {
      body: body,
      amount_minor_units: amount,
      credit_minor_units: credit,
      currency: currency,
      days_before_departure: nil,
      position: 1
    })
  end

  def upsert_card!(arrangement, version)
    body = @card_restrictions.to_s.strip
    raise Error.new("Enter the card restrictions.", code: :invalid) if body.blank?

    upsert_singleton!(arrangement, version, "card_restrictions", {
      body: body,
      amount_minor_units: nil,
      credit_minor_units: nil,
      currency: nil,
      days_before_departure: nil,
      position: 1
    })
  end

  def replace_cancellation!(arrangement, version)
    steps = normalized_steps
    raise Error.new("Enter at least one cancellation step.", code: :invalid) if steps.empty?

    version.supplier_arrangement_cruise_term_definitions.where(term_type: "cancellation_step").destroy_all
    steps.each_with_index.map do |step, index|
      version.supplier_arrangement_cruise_term_definitions.create!(
        agency: @agency,
        departure: arrangement.departure,
        supplier_arrangement: arrangement,
        term_type: "cancellation_step",
        position: index + 1,
        body: step.fetch(:body),
        days_before_departure: step.fetch(:days_before_departure)
      )
    end
  end

  def normalized_steps
    Array(@cancellation_steps).filter_map do |step|
      row = step.to_h.with_indifferent_access
      body = row[:body].to_s.strip
      days = Integer(row[:days_before_departure], exception: false)
      next if body.blank? && days.nil?
      if body.blank? || days.nil? || days.negative?
        raise Error.new("Each cancellation step needs a day count and wording.", code: :invalid)
      end

      { days_before_departure: days, body: body }
    end
  end

  def upsert_singleton!(arrangement, version, term_type, attributes)
    existing = version.supplier_arrangement_cruise_term_definitions.lock.find_by(term_type: term_type)
    if existing
      existing.update!(attributes)
      return existing
    end

    version.supplier_arrangement_cruise_term_definitions.create!(
      attributes.merge(
        agency: @agency,
        departure: arrangement.departure,
        supplier_arrangement: arrangement,
        term_type: term_type
      )
    )
  end

  def replay!(payload)
    key = normalize_idempotency_key(@idempotency_key)
    digest = payload_digest(payload)
    lock_idempotency_slot!(COMMAND_NAME, key)
    existing = AgencyCommandIdempotencyKey.where(
      agency: @agency, command_name: COMMAND_NAME, idempotency_key: key
    ).lock.first
    return nil unless existing
    unless existing.payload_digest == digest
      raise Error.new("That idempotency key was already used for different input.", code: :conflict)
    end

    Result.new(
      status: :replayed,
      record: SupplierArrangementCruiseTermDefinition.find(existing.result_record_id)
    )
  end

  def claim!(payload, record)
    AgencyCommandIdempotencyKey.create!(
      agency: @agency,
      command_name: COMMAND_NAME,
      idempotency_key: normalize_idempotency_key(@idempotency_key),
      payload_digest: payload_digest(payload),
      result_record_type: SupplierArrangementCruiseTermDefinition.name,
      result_record_id: record.id
    )
  rescue ActiveRecord::RecordNotUnique
    raise Error.new("That idempotency key was already used for different input.", code: :conflict)
  end
end
