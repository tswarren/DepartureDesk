MoneyRails.configure do |config|
    config.raise_error_on_money_parsing = true
  end

  Money.disallow_currency_conversion!
