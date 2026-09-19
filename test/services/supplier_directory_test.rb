require "test_helper"

class SupplierDirectoryTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @other = agencies(:cove)
    @admin = agency_users(:harbor_admin)
    @staff = agency_users(:harbor_staff)
    @viewer = agency_users(:harbor_viewer)
    @other_admin = agency_users(:cove_admin)
    ensure_supplier_sequence!(@agency)
    ensure_supplier_sequence!(@other)
  end

  test "creating organization and individual suppliers requires categories and issues SUP references" do
    organization = create_supplier(display_name: "Harbor Cruises", categories: [ "cruise_line" ]).record
    individual = create_supplier(
      kind: "individual",
      first_name: "Ada",
      last_name: "Guide",
      doing_business_as: "Ada Shore Excursions",
      categories: [ "tour_operator_dmc" ]
    ).record

    assert_equal "SUP-000001", organization.supplier_reference
    assert_equal "SUP-000002", individual.supplier_reference
    assert_equal [ "cruise_line" ], organization.category_assignments.pluck(:category_code)
    assert_equal [ "tour_operator_dmc" ], individual.category_assignments.pluck(:category_code)

    assert_raises_with_code(:invalid) do
      create_supplier(display_name: "No Category", categories: [])
    end
  end

  test "duplicate supplier review acknowledgement replays without extra supplier reference or audit" do
    create_supplier(display_name: "Replay Supplier", categories: [ "cruise_line" ])
    error = assert_raises(AgencyCommand::DuplicateReviewRequired) do
      create_supplier(display_name: "Replay Supplier", categories: [ "cruise_line" ])
    end

    created = create_supplier(
      display_name: "Replay Supplier",
      categories: [ "cruise_line" ],
      acknowledgement_token: error.token,
      acknowledgement_reason: "confirmed_distinct"
    )
    replayed = create_supplier(
      display_name: "Replay Supplier",
      categories: [ "cruise_line" ],
      acknowledgement_token: error.token,
      acknowledgement_reason: "confirmed_distinct"
    )

    assert_equal :created, created.status
    assert_equal :replayed, replayed.status
    assert_equal created.record, replayed.record
    assert_equal %w[SUP-000001 SUP-000002], @agency.suppliers.order(:supplier_reference).pluck(:supplier_reference)
    assert_equal 3, @agency.reference_sequences.find_by!(namespace: ReferenceSequence::SUPPLIER_NAMESPACE).next_value
    assert_equal 1, AuditEvent.where(action: "supplier.duplicate_override", subject_id: created.record.id).count
    assert_equal 1, AuditEvent.where(action: "supplier.created", subject_id: created.record.id).count
  end

  test "invalid acknowledgement token restarts duplicate review instead of dead-ending" do
    create_supplier(display_name: "Token Restart Supplier", categories: [ "cruise_line" ])
    error = assert_raises(AgencyCommand::DuplicateReviewRequired) do
      create_supplier(
        display_name: "Token Restart Supplier",
        categories: [ "cruise_line" ],
        acknowledgement_token: "expired-token",
        acknowledgement_reason: "confirmed_distinct"
      )
    end

    assert error.token.present?
    assert_equal 1, error.candidates.size
    assert_equal "Token Restart Supplier", error.candidates.first.display_name
  end

  test "duplicate finder respects kind and supplier-only contact signals" do
    organization = create_supplier(display_name: "Same Kind", legal_name: "Legal Supplier LLC", categories: [ "lodging" ]).record
    individual = create_supplier(kind: "individual", first_name: "Same", last_name: "Kind", categories: [ "tour_operator_dmc" ]).record
    CreateSupplierEmailAddress.new(agency: @agency, actor: @admin, supplier: organization, attributes: { address: "supplier-only@example.com" }).call

    client_org = CreateClientOrganization.new(agency: @agency, actor: @admin, names: { display_name: "Client Email Org" }).call.record
    CreateClientOrganizationEmailAddress.new(
      agency: @agency,
      actor: @admin,
      client_organization: client_org,
      attributes: { address: "client-only@example.com" }
    ).call

    org_hits = FindSupplierDuplicates.call(agency: @agency, actor: @admin, kind: "organization", names: { display_name: "Same Kind" })
    individual_hits = FindSupplierDuplicates.call(agency: @agency, actor: @admin, kind: "individual", names: { first_name: "Same", last_name: "Kind" })
    legal_hits = FindSupplierDuplicates.call(agency: @agency, actor: @admin, kind: "organization", names: { legal_name: "Legal Supplier LLC" })
    client_email_hits = FindSupplierDuplicates.call(agency: @agency, actor: @admin, kind: "organization", names: {}, emails: [ "client-only@example.com" ])
    supplier_email_hits = FindSupplierDuplicates.call(agency: @agency, actor: @admin, kind: "organization", names: {}, emails: [ "supplier-only@example.com" ])

    assert_equal [ organization.id ], org_hits.map(&:id)
    assert_equal [ individual.id ], individual_hits.map(&:id)
    assert_equal [ organization.id ], legal_hits.map(&:id)
    assert_empty client_email_hits
    assert_equal [ organization.id ], supplier_email_hits.map(&:id)
  end

  test "postal duplicate signals require a matching supplier name" do
    supplier = create_supplier(display_name: "Named Postal Supplier", categories: [ "lodging" ]).record
    CreateSupplierPostalAddress.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      attributes: { line_1: "1 Dock", locality: "Somerville", postal_code: "02144", country_code: "US" }
    ).call

    assert_empty FindSupplierDuplicates.call(agency: @agency, actor: @admin, kind: "organization", names: {}, postal_codes: [ "02144" ])
    assert_empty FindSupplierDuplicates.call(agency: @agency, actor: @admin, kind: "organization", names: { display_name: "Unrelated Supplier" }, postal_codes: [ "02144" ])

    postal_hits = FindSupplierDuplicates.call(
      agency: @agency,
      actor: @admin,
      kind: "organization",
      names: { display_name: "Named Postal Supplier" },
      postal_codes: [ "02144" ]
    )
    locality_hits = FindSupplierDuplicates.call(
      agency: @agency,
      actor: @admin,
      kind: "organization",
      names: { display_name: "Named Postal Supplier" },
      localities: [ "Somerville" ]
    )

    assert_equal [ supplier.id ], postal_hits.map(&:id)
    assert_includes postal_hits.first.signals, "name_and_postal_code"
    assert_equal [ supplier.id ], locality_hits.map(&:id)
    assert_includes locality_hits.first.signals, "name_and_locality"
  end

  test "updating supplier names runs duplicate review and inactive suppliers remain editable" do
    create_supplier(display_name: "Existing Supplier", categories: [ "air" ])
    target = create_supplier(display_name: "Update Target", categories: [ "air" ]).record

    error = assert_raises(AgencyCommand::DuplicateReviewRequired) do
      UpdateSupplier.new(
        agency: @agency,
        actor: @admin,
        supplier: target,
        names: { display_name: "Existing Supplier" },
        lock_version: target.lock_version
      ).call
    end

    result = UpdateSupplier.new(
      agency: @agency,
      actor: @admin,
      supplier: target.reload,
      names: { display_name: "Existing Supplier" },
      lock_version: target.lock_version,
      acknowledgement_token: error.token,
      acknowledgement_reason: "confirmed_distinct"
    ).call
    assert_equal :updated, result.status

    inactive = create_supplier(display_name: "Inactive Supplier", categories: [ "lodging" ]).record
    ChangeSupplierStatus.new(agency: @agency, actor: @admin, supplier: inactive, status: "inactive", lock_version: inactive.lock_version).call
    updated = UpdateSupplier.new(
      agency: @agency,
      actor: @admin,
      supplier: inactive.reload,
      names: { display_name: "Inactive Supplier Renamed" },
      lock_version: inactive.lock_version
    ).call
    assert_equal :updated, updated.status
    assert_equal "Inactive Supplier Renamed", inactive.reload.display_name
  end

  test "category replacement rejects empty input supports noop other label and inactive suppliers" do
    supplier = create_supplier(display_name: "Category Supplier", categories: [ "cruise_line" ]).record

    assert_raises_with_code(:invalid) do
      ReplaceSupplierCategories.new(agency: @agency, actor: @admin, supplier: supplier, categories: [], lock_version: supplier.lock_version).call
    end

    noop = ReplaceSupplierCategories.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      categories: [ "cruise_line" ],
      lock_version: supplier.lock_version
    ).call
    assert_equal :noop, noop.status

    changed = ReplaceSupplierCategories.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier.reload,
      categories: [ "lodging", { category_code: "other", other_label: "Expedition partner" } ],
      lock_version: supplier.lock_version
    ).call
    assert_equal :updated, changed.status
    assert_equal %w[lodging other], supplier.category_assignments.order(:category_code).pluck(:category_code)
    assert_equal "Expedition partner", supplier.category_assignments.find_by!(category_code: "other").other_label

    audit = AuditEvent.where(action: "supplier.categories_changed", subject_id: supplier.id).last
    assert_equal %w[cruise_line], audit.details["old_category_codes"]
    assert_equal %w[lodging other], audit.details["new_category_codes"]
    assert_equal true, audit.details["other_label_changed"]
    assert_not audit.details.to_json.include?("Expedition partner")

    ChangeSupplierStatus.new(agency: @agency, actor: @admin, supplier: supplier.reload, status: "inactive", lock_version: supplier.lock_version).call
    inactive_change = ReplaceSupplierCategories.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier.reload,
      categories: [ "air" ],
      lock_version: supplier.lock_version
    ).call
    assert_equal :updated, inactive_change.status
    assert_equal [ "air" ], supplier.category_assignments.pluck(:category_code)
  end

  test "inactivation cascades contact points and reactivation restores neither status nor preference" do
    supplier = create_supplier(display_name: "Lifecycle Supplier", categories: [ "cruise_line" ]).record
    email = CreateSupplierEmailAddress.new(agency: @agency, actor: @admin, supplier: supplier, attributes: { address: "life@example.com", preferred: true }).call.record
    phone = CreateSupplierPhoneNumber.new(agency: @agency, actor: @admin, supplier: supplier, attributes: { number: "202-555-0105", country_code: "US", preferred: true }).call.record
    postal = CreateSupplierPostalAddress.new(agency: @agency, actor: @admin, supplier: supplier, attributes: { line_1: "1 Life", country_code: "US", preferred: true }).call.record
    website = CreateSupplierWebsite.new(agency: @agency, actor: @admin, supplier: supplier, attributes: { url: "life.example", preferred: true }).call.record

    result = ChangeSupplierStatus.new(agency: @agency, actor: @admin, supplier: supplier, status: "inactive", lock_version: supplier.lock_version).call

    assert_equal :updated, result.status
    assert_equal "inactive", supplier.reload.status
    [ email, phone, postal, website ].each do |point|
      assert_equal "inactive", point.reload.status
      assert_not point.preferred?
    end
    audit = AuditEvent.where(action: "supplier.inactivated", subject_id: supplier.id).last
    assert_equal %w[SupplierEmailAddress SupplierPhoneNumber SupplierPostalAddress SupplierWebsite], audit.details["inactivated_contact_points"].map { |point| point["type"] }.sort
    assert_equal [], audit.details["inactivated_locations"]
    assert_equal [], audit.details["inactivated_contacts"]
    assert_equal [], audit.details["inactivated_contact_destinations"]

    ChangeSupplierStatus.new(agency: @agency, actor: @admin, supplier: supplier.reload, status: "active", lock_version: supplier.lock_version).call
    assert_equal "active", supplier.reload.status
    [ email, phone, postal, website ].each do |point|
      assert_equal "inactive", point.reload.status
      assert_not point.preferred?
    end
  end

  test "search browses filters hides contact destinations from viewers deduplicates and truncates" do
    cruise = create_supplier(display_name: "Celebrity Cruises", categories: [ "cruise_line" ]).record
    hotel = create_supplier(display_name: "Inactive Harbor Hotel", categories: [ "lodging" ]).record
    ChangeSupplierStatus.new(agency: @agency, actor: @admin, supplier: hotel, status: "inactive", lock_version: hotel.lock_version).call
    individual = create_supplier(kind: "individual", first_name: "Pat", last_name: "Guide", categories: [ "tour_operator_dmc" ]).record
    dual = create_supplier(display_name: "dual@example.com", categories: [ "air" ]).record
    CreateSupplierEmailAddress.new(agency: @agency, actor: @admin, supplier: dual, attributes: { address: "dual@example.com" }).call
    CreateSupplierEmailAddress.new(agency: @agency, actor: @admin, supplier: cruise, attributes: { address: "hidden-supplier@example.com" }).call

    browse = SearchSupplierDirectory.call(agency: @agency, actor: @admin)
    assert_includes browse.records.map(&:id), cruise.id
    assert_not_includes browse.records.map(&:id), hotel.id

    assert_equal [ hotel.id ], search_ids("Harbor Hotel", status: "inactive")
    assert_equal [ individual.id ], search_ids("Pat Guide", kind: "individual")
    assert_equal [ cruise.id ], SearchSupplierDirectory.call(agency: @agency, actor: @admin, category: "cruise_line").records.map(&:id)
    assert_empty SearchSupplierDirectory.call(agency: @agency, actor: @viewer, query: "hidden-supplier@example.com").records
    assert_equal [ cruise.id ], SearchSupplierDirectory.call(agency: @agency, actor: @viewer, query: "Celebrity Cruises").records.map(&:id)

    email_match = SearchSupplierDirectory.call(agency: @agency, actor: @admin, query: "dual@example.com")
    assert_equal [ dual.id ], email_match.records.map(&:id)
    assert_equal 2, email_match.records.first.rank
    assert_equal "email", email_match.records.first.match_kind

    51.times do |index|
      create_supplier(display_name: format("Trunc Supplier %03d", index), categories: [ "activity_attraction" ])
    end
    truncated = SearchSupplierDirectory.call(agency: @agency, actor: @admin, query: "Trunc Supplier")
    assert_equal 50, truncated.records.size
    assert truncated.truncated
  end

  test "supplier contact creation requires active supplier and preferred commands clear prior primary" do
    supplier = create_supplier(display_name: "Contact Supplier", categories: [ "cruise_line" ]).record
    first = CreateSupplierEmailAddress.new(agency: @agency, actor: @admin, supplier: supplier, attributes: { address: "first@example.com", preferred: true }).call.record
    second = CreateSupplierEmailAddress.new(agency: @agency, actor: @admin, supplier: supplier, attributes: { address: "second@example.com" }).call.record

    result = SetPreferredSupplierEmailAddress.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      record: second,
      lock_version: second.lock_version
    ).call
    assert_equal :updated, result.status
    assert second.reload.preferred?
    assert_not first.reload.preferred?

    ChangeSupplierStatus.new(agency: @agency, actor: @admin, supplier: supplier.reload, status: "inactive", lock_version: supplier.lock_version).call
    assert_raises_with_code(:invalid_state) do
      CreateSupplierEmailAddress.new(agency: @agency, actor: @admin, supplier: supplier.reload, attributes: { address: "inactive-create@example.com" }).call
    end
  end

  test "supplier commands reject cross-agency actors and records" do
    supplier = create_supplier(display_name: "Harbor Supplier", categories: [ "air" ]).record
    other_supplier = create_supplier(agency: @other, actor: @other_admin, display_name: "Cove Supplier", categories: [ "air" ]).record
    audits = AuditEvent.count

    assert_raises_with_code(:unauthorized) do
      SearchSupplierDirectory.call(agency: @other, actor: @admin, query: "Cove")
    end
    assert_raises_with_code(:unauthorized) do
      FindSupplierDuplicates.call(agency: @other, actor: @admin, kind: "organization", names: { display_name: "Cove" })
    end
    assert_raises_with_code(:unauthorized) do
      CreateSupplierEmailAddress.new(agency: @other, actor: @admin, supplier: other_supplier, attributes: { address: "wrong@example.com" }).call
    end
    assert_raises ActiveRecord::RecordNotFound do
      UpdateSupplier.new(agency: @agency, actor: @admin, supplier: other_supplier, names: { display_name: "Hijacked" }, lock_version: other_supplier.lock_version).call
    end
    assert_raises ActiveRecord::RecordNotFound do
      CreateSupplierEmailAddress.new(agency: @agency, actor: @admin, supplier: other_supplier, attributes: { address: "wrong@example.com" }).call
    end
    assert_equal audits, AuditEvent.count
  end

  test "stale no-op contact updates are rejected for every channel" do
    supplier = create_supplier(display_name: "Stale Contact Supplier", categories: [ "air" ]).record
    email = CreateSupplierEmailAddress.new(agency: @agency, actor: @admin, supplier: supplier, attributes: { address: "stale@example.com", preferred: true }).call.record
    phone = CreateSupplierPhoneNumber.new(agency: @agency, actor: @admin, supplier: supplier, attributes: { number: "202-555-0177", country_code: "US", preferred: true }).call.record
    postal = CreateSupplierPostalAddress.new(agency: @agency, actor: @admin, supplier: supplier, attributes: { line_1: "1 Stale Pier", country_code: "US", preferred: true }).call.record
    website = CreateSupplierWebsite.new(agency: @agency, actor: @admin, supplier: supplier, attributes: { url: "stale.example", preferred: true }).call.record

    [
      [ UpdateSupplierEmailAddress, email, { address: email.address, label: email.label, preferred: true } ],
      [ UpdateSupplierPhoneNumber, phone, { number: phone.number, extension: phone.extension, country_code: phone.country_code, label: phone.label, preferred: true } ],
      [ UpdateSupplierPostalAddress, postal, { line_1: postal.line_1, line_2: postal.line_2, locality: postal.locality, region: postal.region, postal_code: postal.postal_code, country_code: postal.country_code, label: postal.label, preferred: true } ],
      [ UpdateSupplierWebsite, website, { url: website.url, label: website.label, preferred: true } ]
    ].each do |command, point, attributes|
      error = assert_raises(AgencyCommand::Error, command.name) do
        command.new(
          agency: @agency,
          actor: @admin,
          supplier: supplier,
          record: point,
          attributes: attributes,
          lock_version: point.lock_version - 1
        ).call
      end
      assert_equal :conflict, error.code, command.name
    end
  end

  test "contact updates audit only fields that changed" do
    supplier = create_supplier(display_name: "Audit Fields Supplier", categories: [ "air" ]).record
    email = CreateSupplierEmailAddress.new(agency: @agency, actor: @admin, supplier: supplier, attributes: { address: "fields@example.com", preferred: true }).call.record

    UpdateSupplierEmailAddress.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      record: email,
      attributes: { address: email.address, label: "Reservations", preferred: true },
      lock_version: email.lock_version
    ).call

    audit = AuditEvent.where(action: "supplier.contact_updated", subject_id: supplier.id).order(:created_at).last
    assert_equal %w[label], audit.details["changed_fields"]
  end

  test "client email addresses are not supplier duplicate candidates" do
    organization = CreateClientOrganization.new(agency: @agency, actor: @admin, names: { display_name: "Client-Only Supplier Test" }).call.record
    CreateClientOrganizationEmailAddress.new(
      agency: @agency,
      actor: @admin,
      client_organization: organization,
      attributes: { address: "not-supplier@example.com" }
    ).call
    supplier = create_supplier(display_name: "Email Supplier", categories: [ "air" ]).record

    assert_empty FindSupplierDuplicates.call(agency: @agency, actor: @admin, kind: "organization", names: {}, emails: [ "not-supplier@example.com" ])
    result = CreateSupplierEmailAddress.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      attributes: { address: "not-supplier@example.com" }
    ).call
    assert_equal :created, result.status
  end

  test "supplier reference exhaustion is surfaced as a domain error" do
    @agency.reference_sequences.find_by!(namespace: ReferenceSequence::SUPPLIER_NAMESPACE).update!(next_value: ReferenceSequence::EXHAUSTED_AT)

    assert_raises_with_code(:reference_exhausted) do
      create_supplier(display_name: "Exhausted Supplier", categories: [ "air" ])
    end
  end

  test "supplier name search can use the intended name index" do
    create_supplier(display_name: "Indexed Supplier Name", categories: [ "air" ])
    assert_search_index(
      Supplier.where(agency_id: @agency.id, display_name_search_key: "indexed supplier name"),
      /index_suppliers_on_agency_and_display_name_key|display_name_search_key/
    )
  end

  test "every supported supplier search branch can use its intended index" do
    supplier = create_supplier(display_name: "Explain Cruise Line", legal_name: "Explain Cruise Line LLC", categories: [ "cruise_line" ]).record
    CreateSupplierEmailAddress.new(agency: @agency, actor: @admin, supplier: supplier, attributes: { address: "explain@example.com" }).call
    CreateSupplierPhoneNumber.new(agency: @agency, actor: @admin, supplier: supplier, attributes: { number: "202-555-0199", country_code: "US" }).call
    CreateSupplierPostalAddress.new(agency: @agency, actor: @admin, supplier: supplier, attributes: { line_1: "1 Explain Pier", locality: "Miami", postal_code: "33101", country_code: "US" }).call
    CreateSupplierWebsite.new(agency: @agency, actor: @admin, supplier: supplier, attributes: { url: "explain.example" }).call

    assert_search_index(
      Supplier.where(agency_id: @agency.id, supplier_reference: supplier.supplier_reference),
      /index_suppliers_on_agency_and_reference|supplier_reference/
    )
    assert_search_index(
      SupplierEmailAddress.where(agency_id: @agency.id, normalized_address: "explain@example.com"),
      /index_supplier_emails_on_agency_and_normalized|normalized_address/
    )
    assert_search_index(
      SupplierPhoneNumber.where(agency_id: @agency.id, normalized_number: "+12025550199"),
      /index_supplier_phones_on_agency_and_e164|normalized_number/
    )
    assert_search_index(
      Supplier.where(agency_id: @agency.id).where("name_search_vector @@ to_tsquery('simple', ?)", "'explain':*"),
      /index_suppliers_on_name_search_vector|name_search_vector|Gin/
    )
    assert_search_index(
      SupplierCategoryAssignment.where(agency_id: @agency.id, category_code: "cruise_line"),
      /index_supplier_category_assignments_on_agency_and_code|category_code/
    )
    assert_search_index(
      SupplierPostalAddress.where(agency_id: @agency.id, postal_code_search_key: "33101"),
      /index_supplier_postals_on_agency_and_postal_code|postal_code_search_key/
    )
    assert_search_index(
      SupplierWebsite.where(agency_id: @agency.id, normalized_host: "explain.example"),
      /index_supplier_websites_on_agency_and_host|normalized_host/
    )
  end

  test "competing set_primary changes clear the prior preferred and reject a stale lock version" do
    supplier = create_supplier(display_name: "Preferred Race Supplier", categories: [ "air" ]).record
    first = CreateSupplierEmailAddress.new(agency: @agency, actor: @admin, supplier: supplier, attributes: { address: "preferred-a@example.com", preferred: true }).call.record
    second = CreateSupplierEmailAddress.new(agency: @agency, actor: @admin, supplier: supplier, attributes: { address: "preferred-b@example.com" }).call.record

    SetPreferredSupplierEmailAddress.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      record: second,
      lock_version: second.lock_version
    ).call

    assert second.reload.preferred?
    assert_not first.reload.preferred?

    stale = assert_raises(AgencyCommand::Error) do
      SetPreferredSupplierEmailAddress.new(
        agency: @agency,
        actor: @admin,
        supplier: supplier,
        record: first,
        lock_version: 0
      ).call
    end
    assert_equal :conflict, stale.code
    assert second.reload.preferred?
    assert_not first.reload.preferred?

    already = SetPreferredSupplierEmailAddress.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      record: second.reload,
      lock_version: second.lock_version
    ).call
    assert_equal :noop, already.status
  end

  test "category replacement racing supplier inactivation resolves through lock_version conflict" do
    supplier = create_supplier(display_name: "Category Race Supplier", categories: [ "cruise_line" ]).record
    lock_version = supplier.lock_version

    ChangeSupplierStatus.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      status: "inactive",
      lock_version: lock_version
    ).call

    conflict = assert_raises(AgencyCommand::Error) do
      ReplaceSupplierCategories.new(
        agency: @agency,
        actor: @admin,
        supplier: supplier,
        categories: [ "lodging" ],
        lock_version: lock_version
      ).call
    end
    assert_equal :conflict, conflict.code
    assert_equal [ "cruise_line" ], supplier.reload.category_assignments.pluck(:category_code)

    ReplaceSupplierCategories.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier.reload,
      categories: [ "lodging" ],
      lock_version: supplier.lock_version
    ).call
    assert_equal [ "lodging" ], supplier.reload.category_assignments.pluck(:category_code)
    assert_equal "inactive", supplier.status
  end

  private

  def create_supplier(
    agency: @agency,
    actor: @admin,
    kind: "organization",
    display_name: nil,
    legal_name: nil,
    first_name: nil,
    last_name: nil,
    doing_business_as: nil,
    categories:,
    acknowledgement_token: nil,
    acknowledgement_reason: nil
  )
    names = { display_name:, legal_name:, first_name:, last_name:, doing_business_as: }.compact
    names[:display_name] ||= "Supplier #{SecureRandom.hex(3)}" if kind == "organization"
    CreateSupplier.new(
      agency: agency,
      actor: actor,
      kind: kind,
      names: names,
      categories: categories,
      acknowledgement_token: acknowledgement_token,
      acknowledgement_reason: acknowledgement_reason
    ).call
  end

  def ensure_supplier_sequence!(agency)
    agency.reference_sequences.find_or_create_by!(namespace: ReferenceSequence::SUPPLIER_NAMESPACE) do |sequence|
      sequence.next_value = 1
    end
  end

  def search_ids(query, status: "active", kind: "all", category: "all", actor: @admin)
    SearchSupplierDirectory.call(
      agency: @agency,
      actor: actor,
      query: query,
      status: status,
      kind: kind,
      category: category
    ).records.map(&:id)
  end

  def assert_raises_with_code(code, &block)
    error = assert_raises(AgencyCommand::Error, &block)
    assert_equal code, error.code
  end

  def assert_search_index(relation, index_matcher)
    plan = nil
    ActiveRecord::Base.transaction do
      ActiveRecord::Base.connection.execute("SET LOCAL enable_seqscan = off")
      plan = relation.explain.inspect
      raise ActiveRecord::Rollback
    end

    assert_match(/Index Scan|Bitmap Index Scan|Bitmap Heap Scan/, plan)
    assert_match(index_matcher, plan)
  end
end
