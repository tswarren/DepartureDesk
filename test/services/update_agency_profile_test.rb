require "test_helper"

class UpdateAgencyProfileTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
  end

  test "an agency admin saves profile fields with one audit event naming the changes" do
    assert_difference -> { AuditEvent.where(action: "agency.profile_updated").count }, 1 do
      update!(
        contact_email: " Hello@Harbor.Example ",
        agency_contact_name: "Robin Reyes",
        phone_number: "(202) 555-0123",
        address_line_1: "1 Dock St",
        address_locality: "Miami",
        address_country_code: "us",
        hold_duration_days: "3",
        installment_buffer_days: "21"
      )
    end

    @agency.reload
    assert_equal "hello@harbor.example", @agency.contact_email
    assert_equal "+12025550123", @agency.phone_normalized_number
    assert_equal "US", @agency.phone_country_code
    assert_equal "US", @agency.address_country_code
    assert_equal 3, @agency.hold_duration_days
    assert_equal 21, @agency.installment_buffer_days
    changed = AuditEvent.where(action: "agency.profile_updated").order(:created_at).last.details["changed"]
    assert_includes changed, "contact_email"
    assert_includes changed, "phone_normalized_number"
    assert_not_includes changed, "name"
  end

  test "display name and contact email are optional to save but block documents (SET-04)" do
    assert_equal [ "Enter the agency contact email." ], @agency.document_profile_blockers
    update!(contact_email: "desk@harbor.example")
    assert_empty @agency.reload.document_profile_blockers
    update!(contact_email: "")
    assert_nil @agency.reload.contact_email
  end

  test "new agencies start with the hold, buffer and SET-06 defaults" do
    assert_equal 2, @agency.hold_duration_days
    assert_equal 14, @agency.installment_buffer_days

    confirmation = @agency.document_inclusions.find_by!(document_family: "confirmation")
    invoice = @agency.document_inclusions.find_by!(document_family: "invoice")
    %w[display_name contact_email phone footer].each do |field|
      assert confirmation.includes?(field), field
      assert invoice.includes?(field), field
    end
    %w[legal_name mailing_address].each do |field|
      assert_not confirmation.includes?(field), field
      assert invoice.includes?(field), field
    end
    %w[agency_contact_name seller_of_travel_disclosure].each do |field|
      assert_not confirmation.includes?(field), field
      assert_not invoice.includes?(field), field
    end
  end

  test "inclusion flags change per document family and are audited by name" do
    update!(inclusions: { "receipt" => { "seller_of_travel_disclosure" => "1", "phone" => "0" } })

    receipt = @agency.document_inclusions.find_by!(document_family: "receipt")
    assert receipt.includes?("seller_of_travel_disclosure")
    assert_not receipt.includes?("phone")
    assert @agency.document_inclusions.find_by!(document_family: "invoice").includes?("phone")
    changed = AuditEvent.where(action: "agency.profile_updated").order(:created_at).last.details["changed"]
    assert_equal %w[inclusions.receipt.phone inclusions.receipt.seller_of_travel_disclosure], changed
  end

  test "the disclosure keeps its line breaks (SET-05)" do
    update!(seller_of_travel_disclosure: "CST 1234567-40\r\nRegistration as a seller of travel\r\ndoes not constitute approval.")
    assert_equal "CST 1234567-40\nRegistration as a seller of travel\ndoes not constitute approval.", @agency.reload.seller_of_travel_disclosure
  end

  test "an unchanged save writes no audit event" do
    assert_no_difference -> { AuditEvent.count } do
      update!(name: @agency.name)
    end
  end

  test "only an agency admin may change the profile" do
    [ agency_users(:harbor_staff), agency_users(:harbor_baseline_staff) ].each do |actor|
      error = assert_raises(AgencyCommand::Error) do
        UpdateAgencyProfile.new(agency: @agency, actor:, attributes: { contact_email: "x@example.com" }).call
      end
      assert_equal :unauthorized, error.code
    end
    assert_nil @agency.reload.contact_email
  end

  test "invalid values are refused" do
    { contact_email: "not-an-email", hold_duration_days: "0", installment_buffer_days: "-1", phone_number: "123" }.each do |field, value|
      error = assert_raises(AgencyCommand::Error) { update!(field => value) }
      assert_equal :invalid, error.code, field
    end
    error = assert_raises(AgencyCommand::Error) { update!(address_locality: "Miami") }
    assert_equal :invalid, error.code
    error = assert_raises(AgencyCommand::Error) { update!(inclusions: { "proposal" => { "phone" => "1" } }) }
    assert_equal :invalid, error.code
  end

  test "the database refuses an address without a first line and an unnormalized email" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Agency.transaction(requires_new: true) { Agency.where(id: @agency.id).update_all(address_locality: "Miami") }
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Agency.transaction(requires_new: true) { Agency.where(id: @agency.id).update_all("contact_email = 'Desk@Harbor.example'") }
    end
  end

  private

  def update!(inclusions: {}, **attributes)
    UpdateAgencyProfile.new(
      agency: @agency, actor: @admin, attributes:, inclusions:, lock_version: @agency.reload.lock_version
    ).call
  end
end
