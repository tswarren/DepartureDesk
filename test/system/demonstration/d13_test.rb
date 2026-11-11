require "application_system_test_case"
require "open3"

# Demonstration case D13 (first-slice charter). Rules: DOC-01, DOC-03,
# DOC-11, DOC-21; ADR 0019.
class DemonstrationD13Test < ApplicationSystemTestCase
  setup do
    set_clock Time.utc(2027, 1, 10, 15)
    @scenario = AlphaScenario.load!(bookings: :paid)
    @alpha = @scenario.alpha
    @scenario.agency.update!(contact_email: "bookings@harbor.example", confirmation_footer: "Bon voyage from the **Harbor** team.")
    set_clock Time.utc(2027, 2, 3, 15)
  end

  teardown do
    AlphaScenario.cleanup!(@scenario)
  end

  test "D13: issued documents are stored as immutable versions" do
    booking = @alpha.bookings.fetch("BK-101")
    receipt = booking.client_trip.client_payments.sole.receipt
    sign_in_from_browser(@scenario.actor, password: M1DirectoryScenario::PASSWORD)

    # 1. Staff issue BK-101's confirmation, invoice and receipt.
    visit client_booking_path(booking, step: "summary")
    [ "Issue booking confirmation", "Issue invoice" ].each do |button|
      accept_confirm { within("#documents") { click_button button } }
      assert_text "issued."
    end
    visit receipt_path(receipt)
    accept_confirm { within("#documents") { click_button "Issue receipt" } }
    assert_text "Receipt PDF issued."

    # 2. Each is a stored version with its number, PDF and SHA-256.
    versions = DocumentVersion.where(agency: @scenario.agency).index_by(&:document_type)
    assert_equal %w[confirmation invoice receipt], versions.keys.sort
    assert_match(/\ACNF-\d{5}\z/, versions["confirmation"].number)
    assert_match(/\AINV-\d{5}\z/, versions["invoice"].number)
    assert_equal receipt.receipt_number, versions["receipt"].number
    versions.each_value { |version| assert_equal version.sha256, Digest::SHA256.hexdigest(version.pdf.download) }

    # 3. The PDFs show the travelers by name and no date of birth.
    texts = versions.transform_values { |version| pdf_text(version) }
    assert_includes texts["confirmation"], "Iris Rowan"
    assert_includes texts["receipt"], "$500.00"
    births = booking.booking_travelers.map { |row| row.traveler.date_of_birth }
    texts.each do |type, text|
      births.each { |born| assert_not_includes text, born.strftime("%B %-d, %Y"), "#{type} shows a date of birth" }
      assert_no_match(/commission|supplier cost|margin/i, text, type)
    end

    # 4. A later footer change leaves the issued confirmation as it was.
    assert_includes texts["confirmation"], "Bon voyage from the Harbor team."
    @scenario.agency.update!(confirmation_footer: "Changed later.")
    assert_equal texts["confirmation"], pdf_text(versions["confirmation"].reload)

    # 5. PostgreSQL refuses to change or delete a version, or remove its PDF.
    assert_raises(ActiveRecord::StatementInvalid) { savepoint { DocumentVersion.where(id: versions["invoice"].id).update_all(number: "INV-99999") } }
    assert_raises(ActiveRecord::StatementInvalid) { savepoint { ActiveStorage::Attachment.where(record: versions["invoice"]).delete_all } }

    # The Documents panel lists each and reflows at 375px.
    [ 1400, 375 ].each do |width|
      resize_window(width)
      [ client_booking_path(booking, step: "summary"), receipt_path(receipt) ].each do |path|
        visit path
        wait_for_turbo
        within("#documents") { assert_text "Issued" }
        assert_no_page_overflow
      end
    end
  end

  private

  def savepoint(&) = ActiveRecord::Base.transaction(requires_new: true, &)

  def pdf_text(version)
    Dir.mktmpdir do |dir|
      path = File.join(dir, "document.pdf")
      File.binwrite(path, version.pdf.download)
      Open3.capture2("pdftotext", "-layout", path, "-").first
    end
  end
end
