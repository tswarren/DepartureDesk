require "test_helper"

class M1DirectoryQueryCountTest < ActionDispatch::IntegrationTest
  setup do
    @celebrity = M1DirectoryScenario.celebrity
    sign_in_as @celebrity.actor
  end

  test "directory list query count does not grow with destination rows" do
    client_baseline = request_query_count { get clients_path }
    20.times do |index|
      CreateClientPersonEmailAddress.new(
        agency: @celebrity.agency,
        actor: @celebrity.actor,
        client_person: @celebrity.martha,
        attributes: { address: "extra-#{index}-#{@celebrity.suffix}@example.test" }
      ).call
    end
    assert_equal client_baseline, request_query_count { get clients_path }

    supplier_baseline = request_query_count { get suppliers_path }
    20.times do |index|
      CreateSupplierEmailAddress.new(
        agency: @celebrity.agency,
        actor: @celebrity.actor,
        supplier: @celebrity.celebrity,
        attributes: { address: "list-#{index}-#{@celebrity.suffix}@example.test" }
      ).call
    end
    assert_equal supplier_baseline, request_query_count { get suppliers_path }
  end

  test "profile query count does not grow per destination row" do
    person_path = client_person_path(@celebrity.martha)
    person_baseline = request_query_count { get person_path }
    15.times do |index|
      CreateClientPersonEmailAddress.new(
        agency: @celebrity.agency,
        actor: @celebrity.actor,
        client_person: @celebrity.martha,
        attributes: { address: "profile-#{index}-#{@celebrity.suffix}@example.test" }
      ).call
    end
    assert_equal person_baseline, request_query_count { get person_path }

    organization = CreateOrganizationClient.new(
      agency: @celebrity.agency, actor: @celebrity.actor,
      names: { display_name: "Query Count Foods" }
    ).call.record.client_organization
    organization_path = client_organization_path(organization)
    organization_baseline = request_query_count { get organization_path }
    15.times do |index|
      CreateClientOrganizationEmailAddress.new(
        agency: @celebrity.agency,
        actor: @celebrity.actor,
        client_organization: organization,
        attributes: { address: "org-#{index}-#{@celebrity.suffix}@example.test" }
      ).call
    end
    assert_equal organization_baseline, request_query_count { get organization_path }

    show_path = supplier_path(@celebrity.celebrity)
    supplier_baseline = request_query_count { get show_path }
    15.times do |index|
      CreateSupplierEmailAddress.new(
        agency: @celebrity.agency,
        actor: @celebrity.actor,
        supplier: @celebrity.celebrity,
        attributes: { address: "show-#{index}-#{@celebrity.suffix}@example.test" }
      ).call
      CreateSupplierLocation.new(
        agency: @celebrity.agency,
        actor: @celebrity.actor,
        supplier: @celebrity.celebrity,
        attributes: { name: "Query Count Dock #{index}" }
      ).call
      CreateSupplierContact.new(
        agency: @celebrity.agency,
        actor: @celebrity.actor,
        supplier: @celebrity.celebrity,
        attributes: { first_name: "Query", last_name: format("Count%02d", index) }
      ).call
    end
    assert_equal supplier_baseline, request_query_count { get show_path }
  end

  private

  def request_query_count
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries.count { |sql| sql.start_with?("SELECT") }
  end
end
