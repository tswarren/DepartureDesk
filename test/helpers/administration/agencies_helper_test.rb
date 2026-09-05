require "test_helper"

module Administration
  class AgenciesHelperTest < ActionView::TestCase
    test "country choices use ISO names and codes" do
      choices = agency_country_code_choices

      assert_includes choices, [ "Canada (CA)", "CA" ]
      assert_includes choices, [ "United States (US)", "US" ]
    end

    test "country choices keep an unrecognized current value" do
      choices = agency_country_code_choices("ZZ")

      assert_equal [ "ZZ", "ZZ" ], choices.first
    end

    test "timezone choices group IANA identifiers" do
      choices = agency_timezone_choices("America/New_York")

      assert_includes choices.fetch("America"), [ "America/New_York", "America/New_York" ]
      assert_includes choices.fetch("America"), [ "America/Toronto", "America/Toronto" ]
      assert_includes choices.fetch("Other"), [ "UTC", "UTC" ]
    end

    test "timezone choices keep an unrecognized current value" do
      choices = agency_timezone_choices("Not/A_Zone")

      assert_equal [ [ "Not/A_Zone", "Not/A_Zone" ] ], choices.fetch("Current")
    end
  end
end
