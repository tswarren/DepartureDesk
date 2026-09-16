ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"
require_relative "test_helpers/m1_directory_scenario"
require_relative "test_helpers/m2_departure_scenario"
require_relative "support/capacity_graph_helper"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    fixtures :all

    TEST_PASSWORD = "password12345"

    setup do
      Rails.cache.clear
    end

    include CapacityGraphHelper
  end
end
