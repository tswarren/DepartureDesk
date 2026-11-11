require "test_helper"
require "open3"

# Slice 1 step 10: issuing the confirmation, invoice and receipt PDFs
# (DOC-01, DOC-03, DOC-09, DOC-11, DOC-21, DOC-24, REF-05, SET-04 to SET-07,
# D-100; ADR 0019; step 10 plan, questions 1 to 10 and 13).
class IssueDocumentTest < ActiveSupport::TestCase
  setup do
    set_clock Time.utc(2027, 1, 10, 15)
    @agency = agencies(:harbor)
    @agency.update!(contact_email: "bookings@harbor.example") if @agency.contact_email.blank?
    @admin = agency_users(:harbor_admin)
    @baseline = agency_users(:harbor_baseline_staff)
    @alpha = AlphaFixture.load!(agency: @agency, actor: @admin, bookings: :paid)
    set_clock Time.utc(2027, 2, 3, 15)
    @booking = @alpha.bookings.fetch("BK-101")
    @receipt = @booking.client_trip.client_payments.sole.receipt
  end

  test "staff issue a confirmation, an invoice and a receipt, each stored once with its PDF, hash and snapshot (DOC-01, DOC-11, REF-05)" do
    confirmation = issue!("confirmation")
    invoice = issue!("invoice")
    receipt = issue!("receipt", receipt: @receipt)

    assert_match(/\ACNF-\d{5}\z/, confirmation.number)
    assert_match(/\AINV-\d{5}\z/, invoice.number)
    assert_equal @receipt.receipt_number, receipt.number, "the receipt's PDF keeps its number"
    [ confirmation, invoice, receipt ].each do |version|
      assert_equal 1, version.version_number
      assert_equal Digest::SHA256.hexdigest(version.pdf.download), version.sha256
      assert_equal DocumentRenderer::TEMPLATE_VERSION, version.template_version
      assert_match(/Chrom/, version.renderer_version)
      assert AuditEvent.exists?(action: "document_version.issued", subject_type: "DocumentVersion", subject_id: version.id, actor_agency_user_id: @baseline.id)
    end
    assert_equal "Nadia Rowan", confirmation.snapshot["recipient"]
    assert_equal [ "Nadia Rowan", "Theo Rowan", "Iris Rowan" ], confirmation.snapshot["travelers"]
    assert_nil confirmation.snapshot["booked_through"]
    assert_equal invoice.snapshot["total"], confirmation.snapshot["total"]
    assert_equal "$500.00", receipt.snapshot["amount"]

    refused = assert_raises(AgencyCommand::Error) { issue!("invoice") }
    assert_match(/Invoice #{invoice.number} is already issued/, refused.message)
    assert_equal 1, @booking.document_versions.count { |version| version.type_invoice? }
  end

  test "documents show no date of birth, supplier cost or commission (DOC-03, CLT-36, CMN-53)" do
    %w[confirmation invoice].each do |type|
      version = issue!(type)
      text = pdf_text(version)
      assert_includes text, "Nadia Rowan"
      @booking.booking_travelers.each do |row|
        born = row.traveler.date_of_birth
        [ born.iso8601, born.strftime("%B %-d, %Y"), born.strftime("%b %-d, %Y"), born.strftime("%m/%d/%Y") ].each do |shown|
          assert_not_includes text, shown, "#{type} shows #{row.display_name}'s date of birth"
          assert_not_includes version.snapshot.to_json, shown
        end
      end
      assert_no_match(/commission|supplier cost|margin|net cost/i, text, type)
    end
  end

  test "an issued document keeps what it showed when the agency changes its profile (DOC-11, SC-DOC-03)" do
    @agency.update!(confirmation_footer: "Thank you for **sailing** with us.")
    version = issue!("confirmation")
    assert_includes pdf_text(version), "Thank you for sailing with us."
    stored = version.pdf.download

    @agency.update!(confirmation_footer: "A new footer.", name: "Harbor Travel Co")
    assert_equal stored, version.reload.pdf.download
    assert_equal "Thank you for **sailing** with us.", version.snapshot["footer_markdown"]
    assert_not_includes pdf_text(version), "A new footer."
  end

  test "PostgreSQL keeps an issued version, its deliveries and its PDF attachment (ADR 0019)" do
    version = issue!("confirmation")
    assert_rejected { DocumentVersion.where(id: version.id).update_all(number: "CNF-99999") }
    assert_rejected { DocumentVersion.where(id: version.id).delete_all }
    assert_rejected { ActiveStorage::Attachment.where(record: version).delete_all }
    delivery = RecordDocumentDelivery.new(agency: @agency, actor: @baseline, version:,
      attributes: { delivery_method: "own_email", recipient: "Nadia Rowan", delivered_on: "2027-02-03" }).call.record
    assert_rejected { DocumentDelivery.where(id: delivery.id).update_all(recipient: "Someone") }
    assert_raises(ActiveRecord::ReadOnlyRecord) { version.update!(sha256: "0" * 64) }
  end

  test "a draft booking or an incomplete agency profile can't be issued (SET-04, question 9)" do
    draft = CreateClientBooking.new(agency: @agency, actor: @baseline, trip: @booking.client_trip).call.record
    refused = assert_raises(AgencyCommand::Error) { issue!("confirmation", booking: draft) }
    assert_match(/isn't confirmed/, refused.message)

    @agency.update_columns(contact_email: nil)
    refused = assert_raises(AgencyCommand::Error) { issue!("invoice") }
    assert_match(/agency profile is complete: Enter the agency contact email/, refused.message)
    assert_equal 0, DocumentVersion.count
  end

  test "a failed issue leaves no version, and the sweep purges its unattached blob (ADR 0019)" do
    sequence = ReferenceSequence.find_by!(agency: @agency, namespace: "invoice")
    before = sequence.next_value
    blobs = ActiveStorage::Blob.count
    command = IssueDocument.new(agency: @agency, actor: @baseline, document_type: "invoice", booking: @booking)
    command.define_singleton_method(:audit!) { |**| raise "audit failed" }
    assert_raises(RuntimeError) { ActiveRecord::Base.transaction(requires_new: true) { command.call } }
    assert_equal 0, DocumentVersion.count
    assert_equal before, sequence.reload.next_value, "the invoice number is returned (REF-05)"
    assert_equal blobs, ActiveStorage::Blob.count, "the uploaded PDF is purged"

    orphan = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("%PDF-1.4"), filename: "orphan.pdf", content_type: "application/pdf")
    orphan.update_columns(created_at: 2.days.ago)
    kept = issue!("confirmation")
    PurgeUnattachedBlobsJob.perform_now
    assert_not ActiveStorage::Blob.exists?(orphan.id)
    assert kept.reload.pdf.attached?
  end

  test "the reseller issues its booking's confirmation only, with Booked through (DOC-09, DOC-24, D-100)" do
    bk105 = @alpha.bookings.fetch("BK-105")
    dana = @alpha.reseller_user
    version = issue!("confirmation", booking: bk105, actor: dana)
    assert_equal "Coral Coast Travel", version.snapshot["booked_through"]
    assert_includes pdf_text(version), "Booked through Coral Coast Travel"

    refused = assert_raises(AgencyCommand::Error) { issue!("invoice", booking: bk105, actor: dana) }
    assert_equal :unauthorized, refused.code
    assert_raises(ActiveRecord::RecordNotFound) { issue!("confirmation", actor: dana) }
    assert_equal :unauthorized, assert_raises(AgencyCommand::Error) { issue!("receipt", receipt: @receipt, actor: dana) }.code

    invoice = issue!("invoice", booking: bk105)
    assert_equal "Coral Coast Travel", invoice.snapshot["booked_through"]
    RecordDocumentDelivery.new(agency: @agency, actor: dana, version:, attributes: { delivery_method: "in_person", recipient: "Mateo Rivera", delivered_on: "2027-02-03" }).call
    assert_raises(ActiveRecord::RecordNotFound) do
      RecordDocumentDelivery.new(agency: @agency, actor: dana, version: invoice, attributes: { delivery_method: "printed", recipient: "Mateo", delivered_on: "2027-02-03" }).call
    end
  end

  test "manual deliveries are recorded by method, recipient and date, and refused when incomplete (DOC-21)" do
    version = issue!("receipt", receipt: @receipt)
    record = ->(attributes) { RecordDocumentDelivery.new(agency: @agency, actor: @baseline, version:, attributes:).call }
    delivery = record.({ delivery_method: "printed", recipient: "Nadia Rowan", delivered_on: "2027-02-03" }).record
    assert_equal [ "printed", "Nadia Rowan", Date.new(2027, 2, 3), @baseline ], [ delivery.delivery_method, delivery.recipient, delivery.delivered_on, delivery.recorded_by ]
    assert AuditEvent.exists?(action: "document_version.delivery_recorded", subject_id: version.id)
    assert_match(/Method must be chosen/, assert_raises(AgencyCommand::Error) { record.({ delivery_method: "fax", recipient: "X", delivered_on: "2027-02-03" }) }.message)
    assert_match(/Recipient must be given/, assert_raises(AgencyCommand::Error) { record.({ delivery_method: "printed", recipient: " ", delivered_on: "2027-02-03" }) }.message)
    assert_match(/can't be in the future/, assert_raises(AgencyCommand::Error) { record.({ delivery_method: "printed", recipient: "X", delivered_on: "2027-03-01" }) }.message)
  end

  private

  def issue!(type, booking: @booking, receipt: nil, actor: @baseline)
    IssueDocument.new(agency: @agency, actor:, document_type: type, booking: (booking unless type == "receipt"), receipt:).call.record
  end

  def pdf_text(version)
    Dir.mktmpdir do |dir|
      path = File.join(dir, "document.pdf")
      File.binwrite(path, version.pdf.download)
      text, status = Open3.capture2("pdftotext", "-layout", path, "-")
      assert status.success?, "pdftotext failed"
      text
    end
  end

  # A refused statement inside a savepoint, so the test's transaction goes on.
  def assert_rejected(error = ActiveRecord::StatementInvalid, &block)
    assert_raises(error) { ActiveRecord::Base.transaction(requires_new: true, &block) }
  end
end
