require "test_helper"

class M1DirectoryQueryCountTest < ActionDispatch::IntegrationTest
  setup do
    @celebrity = M1DirectoryScenario.celebrity
    sign_in_as @celebrity.actor
  end

  test "directory list query count does not grow with destination rows" do
    baseline = request_query_count { get clients_path }

    20.times do |index|
      CreateClientPersonEmailAddress.new(
        agency: @celebrity.agency,
        actor: @celebrity.actor,
        client_person: @celebrity.martha,
        attributes: { address: "extra-#{index}-#{@celebrity.suffix}@example.test" }
      ).call
    end

    grown = request_query_count { get clients_path }
    assert_equal baseline, grown
  end

  test "profile query count does not grow per destination row" do
    path = client_person_path(@celebrity.martha)
    baseline = request_query_count { get path }

    15.times do |index|
      CreateClientPersonEmailAddress.new(
        agency: @celebrity.agency,
        actor: @celebrity.actor,
        client_person: @celebrity.martha,
        attributes: { address: "profile-#{index}-#{@celebrity.suffix}@example.test" }
      ).call
    end

    grown = request_query_count { get path }
    assert_equal baseline, grown
  end

  private

  def request_query_count
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries.count { |sql| sql.start_with?("SELECT") }
  end
end
