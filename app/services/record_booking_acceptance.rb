# Records the client's acceptance of a draft booking's current price and
# terms (BKG-39, BKG-41; S-27). It keeps the accepted total and a
# fingerprint of the price lines, so any later change makes it stale. A
# designated payment counts only when the terms name one, and names the
# recorded client payment on the booking's trip (BKG-41, D-94 (3)). The
# fingerprint covers the proposed installments too, refreshed first so it
# matches what the client is shown (step 8 plan, question 1). Email or signed
# acceptance keeps evidence: an optional file (ADR 0019 amendment) or a
# note of where it is kept.
#
# The first acceptance locks the terms version (BKG-28). A version that
# follows the agency's cancellation tiers gets them copied into its own
# rows first, so a later change to the agency default changes nothing
# accepted (step 6 plan, question 9).
class RecordBookingAcceptance < AgencyCommand
  include BookingCommandSupport
  include UploadedFileCheck

  FIELDS = %w[accepted_by acceptance_method accepted_on note evidence_reference client_payment_id].freeze

  def initialize(agency:, actor:, booking:, attributes:, evidence: nil)
    @agency = agency
    @actor = actor
    @booking = booking
    @attributes = clean(attributes, FIELDS)
    @evidence = evidence.presence
  end

  def call
    ensure_actor!
    io = @evidence && upload_io(@evidence)
    content_type, sha256 = inspect_file!(io, label: "Evidence files") if io

    ActiveRecord::Base.transaction do
      booking = lock_booking!
      ensure_draft!(booking)
      raise Error.new("Choose options and place travelers before recording acceptance; there is no price yet.", code: :invalid_state) if booking.price_lines.empty?

      terms = booking.client_terms_version || raise(Error.new("The Departure has no client terms to accept yet.", code: :invalid_state))
      terms = ClientTermsVersion.lock.find(terms.id)
      method = @attributes["acceptance_method"].to_s
      raise Error.new("Method must be chosen.", code: :invalid) unless method.in?(BookingAcceptance::METHODS)
      if method == "designated_payment" && terms.acceptance_line.nil?
        raise Error.new("Method designated payment counts only when the client terms say so; these terms name no such payment (BKG-41).", code: :invalid)
      end

      lock_terms!(terms)
      refresh_installment_proposals!(booking)
      acceptance = booking.acceptances.new(
        agency: @agency, client_terms_version: terms, accepted_by: @attributes["accepted_by"], acceptance_method: method,
        accepted_on: accepted_on, accepted_total_minor_units: booking.total_minor_units, currency: booking.currency,
        lines_fingerprint: BookingAcceptance.fingerprint(booking), note: @attributes["note"],
        evidence_reference: (@attributes["evidence_reference"] if method.in?(%w[email signed])),
        evidence_sha256: (sha256 if method.in?(%w[email signed])),
        recorded_by: @actor, recorded_at: Clock.current.now, client_payment: designated_payment(method, booking)
      )
      check_evidence!(acceptance)
      # Attached before the insert: the acceptance is append-only, so nothing may update it afterward.
      acceptance.evidence.attach(io:, filename: upload_filename(@evidence, "evidence"), content_type:, identify: false) if io && acceptance.evidence_sha256
      acceptance.save!
      audit_booking!(booking, "client_booking.acceptance_recorded",
        "booking_acceptance_id" => acceptance.id, "acceptance_method" => method, "client_terms_version_id" => terms.id,
        "accepted_total_minor_units" => acceptance.accepted_total_minor_units, "evidence_sha256" => acceptance.evidence_sha256)
      Result.new(status: :created, record: acceptance)
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def accepted_on
    value = @attributes["accepted_on"]
    return Clock.current.today_in(@agency.default_timezone) if value.blank?

    date = value.is_a?(Date) ? value : Date.iso8601(value.to_s)
    raise Error.new("Date accepted can't be in the future.", code: :invalid) if date > Clock.current.today_in(@agency.default_timezone)

    date
  rescue Date::Error
    raise Error.new("Date accepted must be a date, such as 2027-01-12.", code: :invalid)
  end

  # BKG-41: the recorded client payment on this booking's trip that counts as acceptance.
  def designated_payment(method, booking)
    return nil unless method == "designated_payment"

    payment = booking.client_trip.client_payments.find_by(id: @attributes["client_payment_id"]) or
      raise Error.new("Payment must be chosen: record the client's payment on the trip first, then choose it here.", code: :invalid)
    raise Error.new("That payment was reversed and can't count as acceptance.", code: :invalid) if payment.reversed?

    payment
  end

  def check_evidence!(acceptance)
    raise Error.new("Accepted by is required.", code: :invalid) if acceptance.accepted_by.blank?
    if acceptance.acceptance_method.in?(%w[email signed]) && acceptance.evidence_sha256.nil? && acceptance.evidence_reference.blank?
      raise Error.new("Evidence is required for email or signed acceptance: attach the file, say where it is kept, or both.", code: :invalid)
    end
    return unless acceptance.acceptance_method.in?(%w[phone in_person]) && acceptance.note.blank?

    raise Error.new("Note is required for phone or in-person acceptance: who you spoke with and what they accepted.", code: :invalid)
  end

  def lock_terms!(terms)
    return if terms.locked?

    unless terms.overrides_cancellation_tiers?
      @agency.agency_cancellation_tiers.ordered.each do |tier|
        terms.own_cancellation_tiers.create!(
          agency: @agency, copied_from_agency_default: true,
          **tier.attributes.slice("min_days_before_departure", "charge_kind", "percentage", "amount_minor_units", "currency", "service_category")
        )
      end
    end
    terms.update!(locked_at: Clock.current.now)
    audit!(agency: @agency, action: "departure.client_terms_locked", subject: @departure, actor: @actor,
      details: { "client_terms_version_id" => terms.id, "version_number" => terms.version_number, "copied_agency_tiers" => !terms.overrides_cancellation_tiers? })
  end
end
