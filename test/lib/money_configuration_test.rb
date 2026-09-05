require "test_helper"

class MoneyConfigurationTest < ActiveSupport::TestCase
  test "same-currency arithmetic preserves exact minor units" do
    total = Money.new(1_250, "USD") + Money.new(375, "USD")

    assert_equal 1_625, total.fractional
    assert_equal "USD", total.currency.iso_code
  end

  test "mismatched-currency arithmetic is rejected" do
    assert_raises(Money::Bank::DifferentCurrencyError) do
      Money.new(1_000, "USD") + Money.new(1_000, "CAD")
    end
  end

  test "money parsing errors are enabled" do
    assert MoneyRails::Configuration.raise_error_on_money_parsing
  end
end
