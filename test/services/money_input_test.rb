require "test_helper"

# ADR 0001: money input fails rather than becoming a different amount.
class MoneyInputTest < ActiveSupport::TestCase
  test "parses plain and grouped amounts into minor units of the currency" do
    assert_equal 123_450, MoneyInput.minor_units("1,234.50", "USD")
    assert_equal 123_450, MoneyInput.minor_units(" 1234.5 ", "USD")
    assert_equal 0, MoneyInput.minor_units("0", "USD")
    assert_equal 500, MoneyInput.minor_units("500", "JPY")
    assert_nil MoneyInput.minor_units("  ", "USD")
  end

  test "refuses signs, symbols, bad grouping and more decimals than the currency has" do
    [ "-1", "+1", "$1", "1.234", "1,23", "12,34.00", "1.", ".5", "1e3", "5.5" ].each do |entry|
      currency = entry == "5.5" ? "JPY" : "USD"
      assert_raises(MoneyInput::Invalid, entry) { MoneyInput.minor_units(entry, currency) }
    end
  end

  test "displays minor units in the form staff type" do
    assert_equal "1234.50", MoneyInput.display(123_450, "USD")
    assert_equal "", MoneyInput.display(nil, "USD")
  end
end
