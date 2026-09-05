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

  test "requires an uppercase three-letter currency" do
    agency = Agency.new(
      name: "Sunrise Travel",
      default_timezone: "America/New_York",
      default_currency: "usd"
    )

    assert_not agency.valid?
  end
end