# Issues a booking confirmation, an invoice or a receipt's PDF (DOC-01,
# DOC-11; step 10 plan, questions 1 to 3, 7, 9 and 10). It is rendered once
# and stored as an append-only version with its SHA-256 and the snapshot of
# what it shows; every download serves those bytes (ADR 0019).
#
# Every staff user may issue all three (ACC-30). The reseller that owns a
# booking may issue its confirmation only (DOC-24, R-04). A confirmation or
# invoice needs a confirmed booking, and every document needs the agency's
# display name and contact email (SET-04). Each is issued once in Slice 1;
# reissue (DOC-12) is Slice 1b.
#
# Issuing order (ADR 0019, amended 2026-11-10): in one transaction, lock the
# agency and the subject, draw the number (gapless for invoices, REF-05),
# build the snapshot, render and upload the PDF, then write the version, its
# attachment and the audit event. If the transaction fails the uploaded blob
# is purged; PurgeUnattachedBlobsJob removes any a crash leaves behind.
class IssueDocument < AgencyCommand
  include ReferenceIssuance

  def initialize(agency:, actor:, document_type:, booking: nil, receipt: nil)
    @agency = agency
    @actor = actor
    @type = document_type.to_s
    @booking = booking
    @receipt = receipt
  end

  def call
    raise Error.new("Choose a document to issue.", code: :invalid) unless @type.in?(DocumentVersion::TYPES)

    authorize!
    ensure_active_agency!(@agency)
    blob = nil
    ActiveRecord::Base.transaction do
      @agency.lock!
      subject = lock_subject!
      ensure_issuable!(subject)
      issued_at = Clock.current.now
      number = @type == "receipt" ? subject.receipt_number : issue_reference!(@agency, DocumentVersion::NAMESPACES.fetch(@type))
      snapshot = DocumentSnapshot.build(document_type: @type, number:, agency: @agency, issued_at:, **subject_key(subject))
      rendered = DocumentRenderer.render(snapshot, logo: @agency.logo)
      blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(rendered.pdf), filename: "#{number}.pdf", content_type: "application/pdf", identify: false)
      version = DocumentVersion.new(
        agency: @agency, document_type: @type, number:, version_number: 1,
        client_booking: (subject unless @type == "receipt"), receipt: (subject if @type == "receipt"),
        issued_at:, issued_by: @actor, template_version: rendered.template_version, renderer_version: rendered.renderer_version,
        sha256: rendered.sha256, snapshot:
      )
      version.pdf.attach(blob)
      version.save!
      audit!(agency: @agency, action: "document_version.issued", subject: version, actor: @actor, details: {
        "document_version_id" => version.id, "document_type" => @type, "number" => number, "sha256" => rendered.sha256,
        "client_booking_id" => version.client_booking_id, "receipt_id" => version.receipt_id
      }.compact)
      Result.new(status: :created, record: version)
    end
  rescue ActiveRecord::RecordNotUnique
    blob&.purge
    raise Error.new("#{DocumentVersion::TYPE_LABELS.fetch(@type)} is already issued. Reissuing arrives in a later release.", code: :invalid_state)
  rescue DocumentRenderer::Error => error
    raise Error.new(error.message, code: :invalid_state)
  rescue StandardError
    blob&.purge
    raise
  end

  private

  def authorize!
    if reseller_actor?
      raise Error.new(UNAUTHORIZED, code: :unauthorized) unless @type == "confirmation" && @booking

      ensure_reseller_actor!(:reseller_issue_confirmation)
      ResellerScope.new(@actor).bookings.find(@booking.id)
    else
      ensure_directory_actor!(@actor, @agency, :issue_documents)
    end
  end

  def lock_subject!
    if @type == "receipt"
      raise Error.new("Choose the receipt to issue.", code: :invalid) if @receipt.nil?

      @agency.receipts.lock.find(@receipt.id)
    else
      raise Error.new("Choose the booking to issue.", code: :invalid) if @booking.nil?

      @agency.client_bookings.lock.includes(
        :offering, :owner_reseller, :client_terms_version,
        client_trip: [ :departure, { client: %i[client_person client_organization] } ],
        booking_travelers: :traveler, choice_selections: [ :occupants, { option: :choice } ],
        client_charge: [ :lines, :client_terms_version, { installments: { applications: { client_payment: :supplier } } } ]
      ).find(@booking.id)
    end
  end

  def subject_key(subject) = @type == "receipt" ? { receipt: subject } : { booking: subject }

  def ensure_issuable!(subject)
    if (blockers = @agency.document_profile_blockers).any?
      raise Error.new("Documents can't be issued until the agency profile is complete: #{blockers.join(" ")}", code: :invalid_state)
    end
    if @type != "receipt" && !subject.status_confirmed?
      raise Error.new("#{subject.booking_reference} isn't confirmed, so its #{DocumentVersion::TYPE_LABELS.fetch(@type).downcase} can't be issued.", code: :invalid_state)
    end

    existing = @type == "receipt" ? subject.document_versions.first : subject.document_versions.find { |version| version.document_type == @type }
    return if existing.nil?

    raise Error.new("#{DocumentVersion::TYPE_LABELS.fetch(@type)} #{existing.display_number} is already issued. Reissuing arrives in a later release.", code: :invalid_state)
  end
end
