require "test_helper"

class M1DirectorySearchPerformanceTest < ActiveSupport::TestCase
  setup do
    @celebrity = M1DirectoryScenario.celebrity
    @vineyard = M1DirectoryScenario.vineyard
    @agency = @celebrity.agency
    @actor = @celebrity.actor
    @viewer = @celebrity.viewer
    seed_search_records!
  end

  test "composed client search branches use eligible indexes" do
    CLIENT_CASES.each do |query, matcher, extras|
      relation = SearchClientDirectory.composed_relation(agency: @agency, actor: @actor, query: query, **extras)
      assert_index_eligible relation, matcher, "client query #{query.inspect} #{extras.inspect}"
    end
  end

  test "composed supplier search branches use eligible indexes" do
    SUPPLIER_CASES.each do |query, matcher, extras|
      relation = SearchSupplierDirectory.composed_relation(agency: @agency, actor: @actor, query: query, **extras)
      assert_index_eligible relation, matcher, "supplier query #{query.inspect} #{extras.inspect}"
    end
  end

  test "blank browse and kind filters remain index eligible" do
    %w[active inactive all].each do |status|
      assert_index_eligible(
        SearchClientDirectory.composed_relation(agency: @agency, actor: @actor, status:),
        /index_client_people_on_agency|client_people/,
        "client browse #{status}"
      )
      assert_index_eligible(
        SearchSupplierDirectory.composed_relation(agency: @agency, actor: @actor, status:),
        /index_suppliers_on_agency|suppliers/,
        "supplier browse #{status}"
      )
    end

    assert_index_eligible(
      SearchClientDirectory.composed_relation(agency: @agency, actor: @actor, query: "Martha", kind: "people"),
      /index_client_people_on_agency_and_name_search_key|name_search/,
      "people filter"
    )
    westlake_on_celebrity = SearchClientDirectory.call(
      agency: @agency, actor: @actor, query: "Westlake", kind: "organizations"
    )
    assert_empty westlake_on_celebrity.records

    westlake_agency = @vineyard.agency
    assert_index_eligible(
      SearchClientDirectory.composed_relation(agency: westlake_agency, actor: @vineyard.actor, query: "Westlake", kind: "organizations"),
      /index_client_organizations_on_agency_and_display_name_key|display_name/,
      "organizations filter"
    )
    assert_index_eligible(
      SearchSupplierDirectory.composed_relation(agency: @agency, actor: @actor, query: "Celebrity", kind: "organization"),
      /index_suppliers_on_agency_and_display_name_key|display_name/,
      "supplier organization filter"
    )
    assert_index_eligible(
      SearchSupplierDirectory.composed_relation(agency: @agency, actor: @actor, category: "cruise_line"),
      /index_supplier_category_assignments|category/,
      "supplier category filter"
    )
  end

  test "over-100-character queries raise without a directory scan" do
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] if payload[:sql].include?("search_rank") }
    error = ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      assert_raises(AgencyCommand::Error) do
        SearchClientDirectory.call(agency: @agency, actor: @actor, query: "a" * 101)
      end
    end
    assert_equal :invalid, error.code
    assert_empty queries
  end

  test "viewer email and phone queries omit hidden contact branches" do
    email_sql = SearchClientDirectory.composed_relation(
      agency: @agency, actor: @viewer, query: @celebrity.martha_email.address
    )&.to_sql.to_s
    phone_sql = SearchClientDirectory.composed_relation(
      agency: @agency, actor: @viewer, query: "3055550101"
    )&.to_sql.to_s
    assert_no_match(/client_person_email_addresses|client_organization_email_addresses/, email_sql)
    assert_no_match(/client_person_phone_numbers|client_organization_phone_numbers/, phone_sql)
    assert_empty SearchClientDirectory.call(agency: @agency, actor: @viewer, query: @celebrity.martha_email.address).records

    supplier_email_sql = SearchSupplierDirectory.composed_relation(
      agency: @agency, actor: @viewer, query: "alex-#{@celebrity.suffix}@celebrity.example"
    )&.to_sql.to_s
    assert_no_match(/supplier_email_addresses|supplier_contact_email_addresses/, supplier_email_sql)
  end

  test "mixed results deduplicate and keep total order before the 51-row lookahead" do
    51.times do |index|
      CreateClientPerson.new(agency: @agency, actor: @actor, names: { first_name: "Trunc", last_name: format("Person%03d", index) }).call
    end
    outcome = SearchClientDirectory.call(agency: @agency, actor: @actor, query: "Trunc")
    assert_equal 50, outcome.records.size
    assert outcome.truncated
    assert_equal outcome.records.map(&:id).uniq.size, outcome.records.size
    names = outcome.records.map(&:display_name)
    assert_equal names.sort, names
  end

  test "search query count does not grow between 5 and 50 returned records" do
    50.times do |index|
      CreateClientPerson.new(agency: @agency, actor: @actor, names: { first_name: "Capcount", last_name: format("N%03d", index) }).call
    end

    five = search_rank_query_count { SearchClientDirectory.call(agency: @agency, actor: @actor, query: "Capcount N00") }
    fifty = search_rank_query_count { SearchClientDirectory.call(agency: @agency, actor: @actor, query: "Capcount") }
    assert_equal five, fifty
  end

  private

  CLIENT_CASES = [
    [ "CL-000001", /clients|client_reference/, {} ],
    [ "Martha Smith", /index_client_people_on_agency_and_name_search_key|name_search_key/, {} ],
    [ "Martha", /index_client_people_on_name_search_vector|name_search_vector/, {} ],
    [ "martha-mail@example.test", /index_client_person_emails_on_agency_and_normalized|normalized_address/, {} ],
    [ "3055550101", /index_client_person_phones|normalized_number|phone_digits/, {} ],
    [ "33132", /postal_code_search_key|locality_search_key/, {} ]
  ].freeze

  SUPPLIER_CASES = [
    [ "SUP-000001", /index_suppliers_on_agency_and_reference|supplier_reference/, {} ],
    [ "Celebrity Cruises", /index_suppliers_on_agency_and_display_name_key|display_name_search_key/, {} ],
    [ "Celebrity", /index_suppliers_on_name_search_vector|name_search_vector/, {} ],
    [ "cruise line", /index_supplier_category_assignments|category_code/, {} ],
    [ "Port of Miami", /index_supplier_locations_on_agency_and_name_key|name_search_key/, {} ],
    [ "Miami", /index_supplier_locations_on_agency_and_locality|locality_search_key/, {} ],
    [ "Alex Purser", /index_supplier_contacts_on_agency_and_full_name|full_name_search_key/, {} ]
  ].freeze

  def seed_search_records!
    CreateClientPersonEmailAddress.new(
      agency: @agency, actor: @actor, client_person: @celebrity.martha,
      attributes: { address: "martha-mail@example.test" }
    ).call
    CreateClientPersonPostalAddress.new(
      agency: @agency, actor: @actor, client_person: @celebrity.martha,
      attributes: { line_1: "9 Search St", locality: "Miami", postal_code: "33132", country_code: "US" }
    ).call
    CreateSupplierEmailAddress.new(
      agency: @agency, actor: @actor, supplier: @celebrity.celebrity,
      attributes: { address: "search-#{@celebrity.suffix}@celebrity.example" }
    ).call
  end

  def assert_index_eligible(relation, matcher, label)
    assert_not_nil relation, "#{label} produced no composed relation"
    plan = explain(relation)
    assert_match(/Index Scan|Bitmap Index Scan|Bitmap Heap Scan|Index Only Scan/, plan, "#{label}: #{plan}")
    assert_match(matcher, plan, "#{label}: #{plan}")
  end

  def explain(relation)
    plan = nil
    ActiveRecord::Base.transaction do
      ActiveRecord::Base.connection.execute("SET LOCAL enable_seqscan = off")
      plan = relation.explain.inspect
      raise ActiveRecord::Rollback
    end
    plan
  end

  def search_rank_query_count
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] if payload[:sql].include?("search_rank") }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries.size
  end
end
