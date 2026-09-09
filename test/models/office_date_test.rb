require "test_helper"

class OfficeDateTest < ActiveSupport::TestCase
  test "today uses the office timezone rather than UTC" do
    travel_to Time.utc(2026, 9, 6, 5, 0, 0) do
      assert_equal Date.new(2026, 9, 6), OfficeDate.today(offices(:one))
      assert_equal Date.new(2026, 9, 5), OfficeDate.today(offices(:two))
    end
  end
end
