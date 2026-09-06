require "test_helper"

class DirectoryRangeTest < ActiveSupport::TestCase
  test "intersection clips to the overlapping half-open interval" do
    assert_equal [ Date.new(2026, 3, 1), Date.new(2026, 6, 1) ],
      DirectoryRange.intersection(
        Date.new(2026, 1, 1), Date.new(2026, 6, 1),
        Date.new(2026, 3, 1), Date.new(2026, 12, 1)
      )
  end

  test "intersection is nil when ranges do not overlap" do
    assert_nil DirectoryRange.intersection(
      Date.new(2026, 1, 1), Date.new(2026, 3, 1),
      Date.new(2026, 3, 1), Date.new(2026, 6, 1)
    )
  end
end
