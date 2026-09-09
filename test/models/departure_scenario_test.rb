require "test_helper"

class DepartureScenarioTest < ActiveSupport::TestCase
  test "Smith and Napa scenario roots exist without client-sale records" do
    smith = smith_family_reunion_departure!
    napa = napa_wine_country_departure!

    assert_equal Date.new(2027, 7, 12), smith.start_date
    assert_equal "Smith Family Reunion", smith.travel_program.name
    assert_equal "Napa Wine Country Tour", napa.name
    assert_equal 0, smith.party_role_assignments.count
    assert smith.current_group_manager_assignment.current?
    assert_equal 0, DefinedTableProbe.client_sale_tables
  end
end

class DefinedTableProbe
  LATER = %w[
    client_trips
    service_components
    packages
  ].freeze

  def self.client_sale_tables
    LATER.count { |name| ActiveRecord::Base.connection.data_source_exists?(name) }
  end
end
