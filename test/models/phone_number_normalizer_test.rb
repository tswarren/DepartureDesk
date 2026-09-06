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
