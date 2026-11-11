require "test_helper"

# Slice 1 step 10 screens: S-35 on the booking Summary and the receipt page,
# R-04 for the reseller, and downloads through the application only
# (DOC-01, DOC-11, DOC-21, DOC-24; ADR 0019).
class DocumentsControllerTest < ActionDispatch::IntegrationTest
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

  test "staff issue and download the confirmation, invoice and receipt from S-35, and record a delivery (DOC-01, DOC-21)" do
    sign_in_as @baseline
    get client_booking_path(@booking, step: "summary")
    assert_select "#documents li", text: /Booking confirmation\s*Not issued/
    assert_select "#documents button", text: "Issue invoice"

    post client_booking_documents_path(@booking, document_type: "confirmation")
    assert_redirected_to client_booking_path(@booking, step: "summary", anchor: "documents")
    post client_booking_documents_path(@booking, document_type: "invoice")
    confirmation, invoice = @booking.document_versions.reload.sort_by(&:document_type)
    follow_redirect!
    assert_select "#documents li", text: /Booking confirmation\s*#{confirmation.number}\s*Issued/
    assert_select "#documents a[aria-label='Download invoice #{invoice.number}']"

    get document_version_path(invoice)
    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_equal invoice.sha256, Digest::SHA256.hexdigest(response.body)
    assert_match(/sandbox/, response.headers["Content-Security-Policy"])

    post document_version_deliveries_path(confirmation), params: { document_delivery: { delivery_method: "own_email", recipient: "Nadia Rowan", delivered_on: "2027-02-03" } }
    follow_redirect!
    assert_select "#documents li", text: /Delivered Feb 3, 2027, own email, to Nadia Rowan/

    post receipt_document_path(@receipt)
    assert_redirected_to receipt_path(@receipt, anchor: "documents")
    follow_redirect!
    assert_select "#documents li", text: /Receipt\s*#{@receipt.receipt_number}\s*Issued/
  end

  test "another agency's version is not found, and a download whose file changed is an error (ADR 0019)" do
    version = IssueDocument.new(agency: @agency, actor: @admin, document_type: "invoice", booking: @booking).call.record
    sign_in_as agency_users(:cove_admin)
    get document_version_path(version)
    assert_response :not_found

    sign_in_as @baseline
    ActiveStorage::Blob.service.upload(version.pdf.blob.key, StringIO.new("%PDF-1.4 tampered"))
    error = assert_raises(RuntimeError) { get document_version_path(version) }
    assert_match(/failed its SHA-256 check/, error.message)
  end

  test "the reseller issues and downloads its booking's confirmation only (R-04, DOC-24)" do
    bk105 = @alpha.bookings.fetch("BK-105")
    invoice = IssueDocument.new(agency: @agency, actor: @admin, document_type: "invoice", booking: bk105).call.record
    staff_confirmation = IssueDocument.new(agency: @agency, actor: @admin, document_type: "confirmation", booking: @booking).call.record

    sign_in_as @alpha.reseller_user
    get reseller_client_booking_path(bk105, step: "summary")
    assert_select "#documents li", count: 1
    assert_select "#documents button", text: "Issue booking confirmation"
    post reseller_client_booking_documents_path(bk105, document_type: "confirmation")
    assert_redirected_to reseller_client_booking_path(bk105, step: "summary", anchor: "documents")
    confirmation = bk105.document_versions.reload.find(&:type_confirmation?)
    get reseller_document_version_path(confirmation)
    assert_response :success
    assert_equal confirmation.sha256, Digest::SHA256.hexdigest(response.body)
    post reseller_document_version_deliveries_path(confirmation), params: { document_delivery: { delivery_method: "in_person", recipient: "Mateo Rivera", delivered_on: "2027-02-03" } }
    assert_equal 1, confirmation.deliveries.count

    post reseller_client_booking_documents_path(bk105, document_type: "invoice")
    follow_redirect!
    assert_select "[role=alert]", text: /not allowed/
    [ invoice, staff_confirmation ].each do |other|
      get reseller_document_version_path(other)
      assert_response :not_found
    end
    get document_version_path(invoice)
    assert_redirected_to reseller_root_path
  end

  test "the booking Summary's documents don't grow the query count with more deliveries (S-35)" do
    versions = %w[confirmation invoice].map { |type| IssueDocument.new(agency: @agency, actor: @admin, document_type: type, booking: @booking).call.record }
    sign_in_as @baseline
    page = client_booking_path(@booking, step: "summary")
    get page
    before = select_query_count { get page }
    versions.each do |version|
      2.times { RecordDocumentDelivery.new(agency: @agency, actor: @admin, version:, attributes: { delivery_method: "printed", recipient: "Nadia Rowan", delivered_on: "2027-02-03" }).call }
    end
    get page
    assert_equal before, select_query_count { get page }
  end

  private

  def select_query_count
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries.count { |sql| sql.start_with?("SELECT") }
  end
end
