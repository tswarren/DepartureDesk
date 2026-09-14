require "test_helper"

class PhoneNumberNormalizerTest < ActiveSupport::TestCase
  test "stores E.164 and the selected country's national display format" do
    phone = PhoneNumberNormalizer.call(number: "(202) 555-0100", country_code: "US")

    assert_equal "+12025550100", phone.normalized_number
    assert_equal "US", phone.country_code
    assert_equal "(202) 555-0100", phone.number
    assert_match(/\A\+[1-9][0-9]{0,14}\z/, phone.normalized_number)
  end

  test "a number for another country is rejected until that country is selected" do
    error = assert_raises(AgencyCommand::Error) do
      PhoneNumberNormalizer.call(number: "+33 1 42 68 53 00", country_code: "US")
    end
    assert_equal :invalid, error.code

    phone = PhoneNumberNormalizer.call(number: "+33 1 42 68 53 00", country_code: "FR")
    assert_equal "+33142685300", phone.normalized_number
    assert_equal "01 42 68 53 00", phone.number
  end

  test "display uses national format at home and international format abroad" do
    assert_equal "(202) 555-0100", PhoneNumberNormalizer.display(
      normalized_number: "+12025550100", country_code: "US", viewer_country: "US"
    )
    assert_equal "+1 202-555-0100", PhoneNumberNormalizer.display(
      normalized_number: "+12025550100", country_code: "US", viewer_country: "FR"
    )
  end
end
