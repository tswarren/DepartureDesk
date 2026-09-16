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
    celebrity_client_cases.each do |query, matcher, extras|
      relation = SearchClientDirectory.composed_relation(agency: @agency, actor: @actor, query: query, **extras)
      assert_index_eligible relation, matcher, "client query #{query.inspect} #{extras.inspect}"
    end

    vineyard_client_cases.each do |query, matcher, extras|
      relation = SearchClientDirectory.composed_relation(
        agency: @vineyard.agency, actor: @vineyard.actor, query: query, **extras
      )
      assert_index_eligible relation, matcher, "vineyard client query #{query.inspect} #{extras.inspect}"
    end
  end

  test "composed supplier search branches use eligible indexes" do
    supplier_cases.each do |query, matcher, extras|
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
      SearchClientDirectory.composed_relation(agency: @agency, actor: @actor, query: "Martha", kind: "all"),
      /index_client_people_on_agency_and_name_search_key|name_search/,
      "client all filter"
    )
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
      SearchSupplierDirectory.composed_relation(agency: @agency, actor: @actor, query: "Indie", kind: "individual"),
      /index_suppliers_on_agency_and_name|name_search|suppliers/,
      "supplier individual filter"
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

    supplier_queries = []
    supplier_callback = ->(*, payload) { supplier_queries << payload[:sql] if payload[:sql].include?("search_rank") }
    supplier_error = ActiveSupport::Notifications.subscribed(supplier_callback, "sql.active_record") do
      assert_raises(AgencyCommand::Error) do
        SearchSupplierDirectory.call(agency: @agency, actor: @actor, query: "b" * 101)
      end
    end
    assert_equal :invalid, supplier_error.code
    assert_empty supplier_queries
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
    supplier_phone_sql = SearchSupplierDirectory.composed_relation(
      agency: @agency, actor: @viewer, query: "3055550199"
    )&.to_sql.to_s
    assert_no_match(/supplier_email_addresses|supplier_contact_email_addresses/, supplier_email_sql)
    assert_no_match(/supplier_phone_numbers|supplier_contact_phone_numbers/, supplier_phone_sql)
  end

  test "mixed results deduplicate and keep total order before the 51-row lookahead" do
    51.times do |index|
      CreateClientPerson.new(agency: @agency, actor: @actor, names: { first_name: "Trunc", last_name: format("Person%03d", index) }).call
    end
    client_rows = SearchClientDirectory.composed_relation(agency: @agency, actor: @actor, query: "Trunc").to_a
    assert_operator client_rows.size, :>=, 51
    outcome = SearchClientDirectory.call(agency: @agency, actor: @actor, query: "Trunc")
    assert_equal 50, outcome.records.size
    assert outcome.truncated
    assert_equal outcome.records.map(&:id).uniq.size, outcome.records.size
    names = outcome.records.map(&:display_name)
    assert_equal names.sort, names

    17.times do |index|
      CreateSupplier.new(
        agency: @agency, actor: @actor, kind: "organization",
        names: { display_name: format("TruncMix S%02d", index) },
        categories: [ "air" ]
      ).call
      CreateSupplierLocation.new(
        agency: @agency, actor: @actor, supplier: @celebrity.celebrity,
        attributes: { name: format("TruncMix L%02d", index) }
      ).call
      CreateSupplierContact.new(
        agency: @agency, actor: @actor, supplier: @celebrity.celebrity,
        attributes: { first_name: "TruncMix", last_name: format("C%02d", index) }
      ).call
    end

    supplier_rows = SearchSupplierDirectory.composed_relation(agency: @agency, actor: @actor, query: "TruncMix").to_a
    assert_operator supplier_rows.size, :>=, 51
    kinds = supplier_rows.first(51).map { |row| row.read_attribute("result_kind") }
    assert_operator kinds.uniq.size, :>=, 2
    supplier_outcome = SearchSupplierDirectory.call(agency: @agency, actor: @actor, query: "TruncMix")
    assert_equal 50, supplier_outcome.records.size
    assert supplier_outcome.truncated
    assert_equal supplier_outcome.records.map(&:id).uniq.size, supplier_outcome.records.size
  end

  test "search query count does not grow between 5 and 50 returned records" do
    50.times do |index|
      CreateClientPerson.new(agency: @agency, actor: @actor, names: { first_name: "Capcount", last_name: format("N%03d", index) }).call
      CreateSupplier.new(
        agency: @agency, actor: @actor, kind: "organization",
        names: { display_name: format("Supcount N%03d", index) },
        categories: [ "air" ]
      ).call
    end

    five = search_rank_query_count { SearchClientDirectory.call(agency: @agency, actor: @actor, query: "Capcount N00") }
    fifty = search_rank_query_count { SearchClientDirectory.call(agency: @agency, actor: @actor, query: "Capcount") }
    assert_equal five, fifty

    supplier_five = search_rank_query_count { SearchSupplierDirectory.call(agency: @agency, actor: @actor, query: "Supcount N00") }
    supplier_fifty = search_rank_query_count { SearchSupplierDirectory.call(agency: @agency, actor: @actor, query: "Supcount") }
    assert_equal supplier_five, supplier_fifty
  end

  private

  def celebrity_client_cases
    [
      [ "CL-000001", /clients|client_reference/, {} ],
      [ "Martha Smith", /index_client_people_on_agency_and_name_search_key|name_search_key/, {} ],
      [ "Martha", /index_client_people_on_name_search_vector|name_search_vector/, {} ],
      [ "martha-mail@example.test", /index_client_person_emails_on_agency_and_normalized|normalized_address/, {} ],
      [ "3055550101", /index_client_person_phones|normalized_number|phone_digits/, {} ],
      [ "33132", /index_client_person_postals_on_agency_and_postal_code|postal_code_search_key/, {} ],
      [ "Miami", /index_client_person_postals_on_agency_and_locality|locality_search_key/, {} ]
    ]
  end

  def vineyard_client_cases
    [
      [ @vineyard.westlake_client.client_reference, /clients|client_reference/, {} ],
      [ "Westlake Foods", /index_client_organizations_on_agency_and_display_name_key|display_name_search_key/, {} ],
      [ "Westlake", /index_client_organizations_on_name_search_vector|name_search_vector/, {} ],
      [ "westlake@example.test", /index_client_org_emails_on_agency_and_normalized|normalized_address/, {} ],
      [ "6175550199", /index_client_org_phones|normalized_number|phone_digits/, {} ],
      [ "01742", /index_client_org_postals_on_agency_and_postal_code|postal_code_search_key/, {} ],
      [ "Concord", /index_client_org_postals_on_agency_and_locality|locality_search_key/, {} ],
      [ "westlake-foods.example", /index_client_org_websites_on_agency_and_host|normalized_host/, {} ]
    ]
  end

  def supplier_cases
    [
      [ "SUP-000001", /index_suppliers_on_agency_and_reference|supplier_reference/, {} ],
      [ "Celebrity Cruises", /index_suppliers_on_agency_and_display_name_key|display_name_search_key/, {} ],
      [ "Celebrity", /index_suppliers_on_name_search_vector|name_search_vector/, {} ],
      [ "cruise line", /index_supplier_category_assignments|category_code/, {} ],
      [ "search-#{@celebrity.suffix}@celebrity.example", /index_supplier_emails_on_agency_and_normalized|normalized_address/, {} ],
      [ "3055550188", /index_supplier_phones_on_agency_and_e164|normalized_number|phone_digits/, {} ],
      [ "90210", /index_supplier_postals_on_agency_and_postal_code|postal_code_search_key/, {} ],
      [ "Beverly", /index_supplier_postals_on_agency_and_locality|locality_search_key/, {} ],
      [ "celebrity-search.example", /index_supplier_websites_on_agency_and_host|normalized_host/, {} ],
      [ "Port of Miami", /index_supplier_locations_on_agency_and_name_key|name_search_key/, {} ],
      [ "Port", /index_supplier_locations_on_name_search_vector|name_search_vector/, {} ],
      [ "Miami", /index_supplier_locations_on_agency_and_locality|locality_search_key/, {} ],
      [ "33132", /index_supplier_locations_on_agency_and_postal_code|postal_code_search_key/, {} ],
      [ "Alex Purser", /index_supplier_contacts_on_agency_and_full_name|full_name_search_key/, {} ],
      [ "Alex", /index_supplier_contacts_on_name_search_vector|name_search_vector/, {} ],
      [ "alex-#{@celebrity.suffix}@celebrity.example", /index_supplier_contact_emails_on_agency_and_normalized|normalized_address/, {} ],
      [ "3055550199", /index_supplier_contact_phones_on_agency_and_e164|normalized_number|phone_digits/, {} ]
    ]
  end

  def seed_search_records!
    CreateClientPersonEmailAddress.new(
      agency: @agency, actor: @actor, client_person: @celebrity.martha,
      attributes: { address: "martha-mail@example.test" }
    ).call
    CreateClientPersonPostalAddress.new(
      agency: @agency, actor: @actor, client_person: @celebrity.martha,
      attributes: { line_1: "9 Search St", locality: "Miami", postal_code: "33132", country_code: "US" }
    ).call
    CreateClientOrganizationEmailAddress.new(
      agency: @vineyard.agency, actor: @vineyard.actor, client_organization: @vineyard.westlake,
      attributes: { address: "westlake@example.test" }
    ).call
    CreateClientOrganizationPhoneNumber.new(
      agency: @vineyard.agency, actor: @vineyard.actor, client_organization: @vineyard.westlake,
      attributes: { number: "617-555-0199", country_code: "US" }
    ).call
    CreateClientOrganizationPostalAddress.new(
      agency: @vineyard.agency, actor: @vineyard.actor, client_organization: @vineyard.westlake,
      attributes: { line_1: "1 Concord Rd", locality: "Concord", postal_code: "01742", country_code: "US" }
    ).call
    CreateClientOrganizationWebsite.new(
      agency: @vineyard.agency, actor: @vineyard.actor, client_organization: @vineyard.westlake,
      attributes: { url: "https://westlake-foods.example" }
    ).call
    CreateSupplierEmailAddress.new(
      agency: @agency, actor: @actor, supplier: @celebrity.celebrity,
      attributes: { address: "search-#{@celebrity.suffix}@celebrity.example" }
    ).call
    CreateSupplierPhoneNumber.new(
      agency: @agency, actor: @actor, supplier: @celebrity.celebrity,
      attributes: { number: "305-555-0188", country_code: "US" }
    ).call
    CreateSupplierPostalAddress.new(
      agency: @agency, actor: @actor, supplier: @celebrity.celebrity,
      attributes: { line_1: "1 Beverly Blvd", locality: "Beverly", postal_code: "90210", country_code: "US" }
    ).call
    CreateSupplierWebsite.new(
      agency: @agency, actor: @actor, supplier: @celebrity.celebrity,
      attributes: { url: "https://celebrity-search.example" }
    ).call
    CreateSupplier.new(
      agency: @agency, actor: @actor, kind: "individual",
      names: { first_name: "Indie", last_name: "Guide" },
      categories: [ "air" ]
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
