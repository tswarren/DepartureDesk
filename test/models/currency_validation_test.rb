require "test_helper"

# Money::Currency.find returns nil for an unknown code, so the currency
# checks use Money::Currency.new, which raises. ADR 0001: explicit, valid
# currencies only.
class CurrencyValidationTest < ActiveSupport::TestCase
  test "an unknown three-letter code is refused as an agency default currency" do
    agency = agencies(:harbor)
    agency.default_currency = "ZZZ"
    assert_not agency.valid?
    assert_includes agency.errors[:default_currency], "is not a supported currency"
  end

  test "an unknown code is refused for a Departure, by model and by command" do
    departure = agencies(:harbor).departures.new(name: "Currency", departure_reference: "DEP-7777", operating_currency: "ZZZ")
    assert_not departure.valid?

    error = assert_raises(AgencyCommand::Error) do
      CreateDeparture.new(agency: agencies(:harbor), actor: agency_users(:harbor_admin), attributes: { name: "Bad Currency", operating_currency: "ZZZ" }).call
    end
    assert_equal :invalid, error.code
  end

  test "known codes still pass" do
    assert CreateDeparture.new(agency: agencies(:harbor), actor: agency_users(:harbor_admin), attributes: { name: "Euro", operating_currency: "EUR" }).call.record.persisted?
  end
end
