ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"
require_relative "test_helpers/m1_directory_scenario"
require_relative "test_helpers/m2_departure_scenario"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    fixtures :all

    TEST_PASSWORD = "password12345"

    setup do
      Rails.cache.clear
      Clock.reset!
    end

    teardown do
      Clock.reset!
    end

    # Fixes Clock.current at an instant for the rest of the test and returns
    # the clock, which the test can advance.
    def set_clock(at)
      Clock.current = Clock.fixed(at)
    end
  end
end
