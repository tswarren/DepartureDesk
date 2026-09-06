require "test_helper"

class CountryReferenceTest < ActiveSupport::TestCase
  test "options have unique labels and country codes" do
    options = CountryReference.options
    labels = options.map(&:first)
    codes = options.map(&:last)

    assert_equal labels, labels.uniq
    assert_equal codes, codes.uniq
    assert_includes codes, "US"
    assert_equal 1, codes.count("US")
  end
end
