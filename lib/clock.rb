# The source of the current instant for domain code (first-slice charter,
# technical baseline: Test clock). New code reads Clock.current instead of
# calling Time.current, so tests can run the Alpha fixture at any date from
# Nov 2026 to Nov 2027.
#
# Clock.current is process-wide rather than per-thread, so a system test's app
# server thread sees the clock its test set. Parallel test workers are separate
# processes and do not share it.
module Clock
  # Reads the real time through Time.current, so Rails' travel_to still applies.
  class System
    def now
      Time.current
    end

    def today_in(time_zone)
      now.in_time_zone(time_zone).to_date
    end
  end

  # Stays at one instant until a test moves it.
  class Fixed
    def initialize(at)
      @now = Clock.instant(at)
    end

    def now
      @now
    end

    def today_in(time_zone)
      now.in_time_zone(time_zone).to_date
    end

    def advance(duration)
      @now += duration
      self
    end

    def travel_to(at)
      @now = Clock.instant(at)
      self
    end
  end

  SYSTEM = System.new

  class << self
    def current
      @current || SYSTEM
    end

    def current=(clock)
      raise ArgumentError, "A clock must respond to now and today_in" unless clock.respond_to?(:now) && clock.respond_to?(:today_in)
      raise "The clock cannot be replaced in production" if Rails.env.production?

      @current = clock
    end

    def reset!
      @current = nil
    end

    def fixed(at)
      Fixed.new(at)
    end

    # Runs the block with clock as Clock.current, then restores the previous clock.
    def use(clock)
      previous = @current
      self.current = clock
      yield clock
    ensure
      @current = previous
    end

    # Accepts only values that name an instant; a bare date or an offset-free
    # string is ambiguous about the time zone.
    def instant(at)
      case at
      when ActiveSupport::TimeWithZone, Time, DateTime
        at.to_time.in_time_zone
      else
        raise ArgumentError, "A clock needs a Time, not #{at.class}"
      end
    end
  end
end
