require "test_helper"

class PhoneNumberNormalizerTest < ActiveSupport::TestCase
  test "preserves display digits and stores E.164 when valid" do
    result = PhoneNumberNormalizer.normalize("(617) 555-0100", default_country: "US")

    assert_equal "(617) 555-0100", result.display_number
    assert_equal "6175550100", result.normalized_digits
    assert_equal "valid", result.parse_status
    assert_equal "+16175550100", result.e164_number
    assert_equal "US", result.parsed_country_code
  end

  test "rejects a value with no digits" do
    error = assert_raises(PhoneNumberNormalizer::Error) do
      PhoneNumberNormalizer.normalize("call me")
    end
    assert_match(/digits/, error.message)
  end

  test "formats a home-country number nationally and appends an extension" do
    result = PhoneNumberNormalizer.normalize("415-555-0199", default_country: "US")

    assert_equal "(415) 555-0199", PhoneNumberNormalizer.format(
      display_number: result.display_number,
      e164_number: result.e164_number,
      parsed_country_code: result.parsed_country_code,
      home_country: "US"
    )
    assert_equal "(415) 555-0199 ext. 12", PhoneNumberNormalizer.format(
      display_number: result.display_number,
      e164_number: result.e164_number,
      parsed_country_code: result.parsed_country_code,
      extension: "12",
      home_country: "US"
    )
  end

  test "formats a foreign number in international form" do
    result = PhoneNumberNormalizer.normalize("+44 20 7946 0958", default_country: "US")

    assert_equal "+44 20 7946 0958", PhoneNumberNormalizer.format(
      display_number: result.display_number,
      e164_number: result.e164_number,
      parsed_country_code: result.parsed_country_code,
      home_country: "US"
    )
  end

  test "falls back to the stored display number when the value cannot be parsed" do
    assert_equal "desk line", PhoneNumberNormalizer.format(
      display_number: "desk line",
      home_country: "US"
    )
    assert_equal "desk line ext. 9", PhoneNumberNormalizer.format(
      display_number: "desk line",
      extension: "9",
      home_country: "US"
    )
  end
end

class EmailAddressNormalizerTest < ActiveSupport::TestCase
  test "trims and case-folds without inventing a different destination" do
    parsed = EmailAddressNormalizer.normalize("  Alex.Morgan@Example.COM ")

    assert_equal "Alex.Morgan@Example.COM", parsed[:display_address]
    assert_equal "alex.morgan@example.com", parsed[:normalized_address]
  end

  test "rejects missing or extra at signs" do
    assert_raises(EmailAddressNormalizer::Error) { EmailAddressNormalizer.normalize("alex.example.com") }
    assert_raises(EmailAddressNormalizer::Error) { EmailAddressNormalizer.normalize("alex@home@example.com") }
  end
end
