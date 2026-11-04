require "test_helper"

class ClockTest < ActiveSupport::TestCase
  NEW_YORK = "America/New_York"

  test "the system clock is the default and follows Time.current" do
    assert_same Clock::SYSTEM, Clock.current

    travel_to Time.utc(2026, 11, 10, 14, 0) do
      assert_equal Time.utc(2026, 11, 10, 14, 0), Clock.current.now
    end
  end

  test "a fixed clock stays at its instant" do
    clock = Clock.fixed(Time.utc(2027, 10, 22, 12, 0))

    assert_equal Time.utc(2027, 10, 22, 12, 0), clock.now
    assert_equal clock.now, clock.now
  end

  test "a fixed clock advances and travels" do
    clock = Clock.fixed(Time.utc(2026, 11, 10, 14, 0))

    clock.advance(2.days)
    assert_equal Time.utc(2026, 11, 12, 14, 0), clock.now

    clock.travel_to(Time.find_zone!(NEW_YORK).local(2027, 10, 23, 0, 1))
    assert_equal Time.utc(2027, 10, 23, 4, 1), clock.now
  end

  test "today is the date in the given time zone" do
    clock = Clock.fixed(Time.utc(2026, 11, 11, 3, 30))

    assert_equal Date.new(2026, 11, 10), clock.today_in(NEW_YORK)
    assert_equal Date.new(2026, 11, 11), clock.today_in("UTC")
  end

  test "a fixed clock rejects values that do not name an instant" do
    assert_raises(ArgumentError) { Clock.fixed(Date.new(2026, 11, 10)) }
    assert_raises(ArgumentError) { Clock.fixed("2026-11-10 09:00") }
  end

  test "use sets the clock for the block and restores it, even after an error" do
    clock = Clock.fixed(Time.utc(2027, 3, 1, 12, 0))

    Clock.use(clock) { assert_same clock, Clock.current }
    assert_same Clock::SYSTEM, Clock.current

    assert_raises(RuntimeError) { Clock.use(clock) { raise "boom" } }
    assert_same Clock::SYSTEM, Clock.current
  end

  test "set_clock replaces the clock for the rest of the test" do
    clock = set_clock(Time.utc(2027, 8, 1, 12, 0))

    assert_same clock, Clock.current
    assert_equal Time.utc(2027, 8, 1, 12, 0), Clock.current.now
  end

  test "the clock is reset before each test" do
    assert_same Clock::SYSTEM, Clock.current
  end

  test "the clock cannot be replaced in production" do
    original = Rails.env
    Rails.env = "production"
    assert_raises(RuntimeError) { Clock.current = Clock.fixed(Time.utc(2026, 11, 10)) }
  ensure
    Rails.env = original
  end

  test "a replacement clock must answer now and today_in" do
    assert_raises(ArgumentError) { Clock.current = Object.new }
  end
end
