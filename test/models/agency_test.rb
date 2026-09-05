require "test_helper"

class AgencyTest < ActiveSupport::TestCase
  test "assigns a UUIDv7 before persistence" do
    agency = Agency.new(
      name: "Sunrise Travel",
      default_timezone: "America/New_York",
      default_currency: "USD"
    )

    assert agency.id.present?
    assert agency.id.split("-").fetch(2).start_with?("7")
    assert_not agency.persisted?
  end

  test "preserves its preassigned ID after creation" do
    agency = Agency.new(
      name: "Sunrise Travel",
      default_timezone: "America/New_York",
      default_currency: "USD"
    )
    original_id = agency.id

    agency.save!

    assert_equal original_id, agency.reload.id
  end

  test "requires a recognized IANA timezone" do
    agency = Agency.new(
      name: "Sunrise Travel",
      default_timezone: "Eastern",
      default_currency: "USD"
    )

    assert_not agency.valid?
    assert_includes agency.errors[:default_timezone],
      "is not a recognized IANA timezone"
  end

  test "does not destroy an agency that still has memberships" do
    assert_raises(ActiveRecord::DeleteRestrictionError) do
      agencies(:one).destroy!
    end
  end

  test "normalizes a blank legal name to nil" do
    agency = agencies(:one)
    agency.update!(legal_name: "  ")

    assert_nil agency.reload.legal_name
  end

  test "rejects a whitespace-only legal name in the database" do
    agency = agencies(:one)

    assert_raises(ActiveRecord::StatementInvalid) do
      Agency.transaction(requires_new: true) do
        Agency.connection.execute(
          "UPDATE agencies SET legal_name = '   ' WHERE id = '#{agency.id}'"
        )
      end
    end
  end

  test "formal_name uses legal_name when present" do
    agency = agencies(:one)
    agency.update!(legal_name: "Sunrise Travel LLC")

    assert_equal "Sunrise Travel LLC", agency.formal_name
  end

  test "formal_name falls back to the display name" do
    assert_equal "Sunrise Travel", agencies(:one).formal_name
  end

  test "normalizes country_code to uppercase" do
    agency = agencies(:one)
    agency.update!(country_code: "ca")

    assert_equal "CA", agency.reload.country_code
  end

  test "rejects an invalid country_code in the model" do
    agency = agencies(:one)
    agency.country_code = "USA"

    assert_not agency.valid?
  end

  test "rejects an invalid country_code in the database" do
    agency = agencies(:one)

    assert_raises(ActiveRecord::StatementInvalid) do
      Agency.transaction(requires_new: true) do
        Agency.connection.execute(
          "UPDATE agencies SET country_code = 'us' WHERE id = '#{agency.id}'"
        )
      end
    end
  end

  test "raises on a stale agency update" do
    agency = agencies(:one)
    stale = Agency.find(agency.id)

    agency.update!(name: "Sunrise Travel Group")

    assert_raises(ActiveRecord::StaleObjectError) do
      stale.update!(legal_name: "Sunrise Travel LLC")
    end
  end

  test "requires an uppercase three-letter currency" do
    agency = Agency.new(
      name: "Sunrise Travel",
      default_timezone: "America/New_York",
      default_currency: "usd"
    )

    assert_not agency.valid?
  end
end
