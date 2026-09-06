require "test_helper"

class DirectoryDateTest < ActiveSupport::TestCase
  test "today uses the agency timezone rather than UTC Date.current" do
    travel_to Time.utc(2026, 9, 6, 5, 0, 0) do
      assert_equal Date.new(2026, 9, 6), DirectoryDate.today(agencies(:one))
      assert_equal Date.new(2026, 9, 5), DirectoryDate.today(agencies(:two))
      assert_equal Date.new(2026, 9, 6), Date.current
    end
  end

  test "inclusive UI end dates convert to exclusive effective_until" do
    assert_equal Date.new(2026, 10, 1), DirectoryDate.exclusive_until(Date.new(2026, 9, 30))
    assert_equal Date.new(2026, 9, 30), DirectoryDate.inclusive_end(Date.new(2026, 10, 1))
    assert_nil DirectoryDate.exclusive_until(nil)
    assert_nil DirectoryDate.inclusive_end(nil)
  end
end
