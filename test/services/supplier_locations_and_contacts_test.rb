require "test_helper"

class SupplierLocationsAndContactsTest < ActiveSupport::TestCase
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

  test "creating location and contact requires an active supplier" do
    supplier = create_supplier(display_name: "Active Host", categories: [ "cruise_line" ]).record
    location = create_location(supplier, name: "Miami Terminal").record
    contact = create_contact(supplier, first_name: "Ada", last_name: "Guide").record

    assert_equal "active", location.status
    assert_equal "active", contact.status
    assert_equal supplier.id, location.supplier_id
    assert_equal supplier.id, contact.supplier_id

    ChangeSupplierStatus.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      status: "inactive",
      lock_version: supplier.lock_version
    ).call

    assert_raises_with_code(:invalid_state) do
      create_location(supplier.reload, name: "Inactive Create Pier")
    end
    assert_raises_with_code(:invalid_state) do
      create_contact(supplier.reload, first_name: "No", last_name: "Create")
    end
  end

  test "location duplicate review uses exact postal and name locality without phone signals" do
    supplier = create_supplier(display_name: "Postal Host", categories: [ "lodging" ]).record
    existing = create_location(
      supplier,
      name: "Harbor Dock",
      address_line_1: "1 Dock St",
      address_locality: "Somerville",
      address_postal_code: "02144",
      address_country_code: "US",
      phone_number: "202-555-0100",
      phone_country_code: "US"
    ).record

    exact = FindSupplierLocationDuplicates.call(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      name: "Different Name",
      address: {
        address_line_1: "1 Dock St",
        address_locality: "Somerville",
        address_postal_code: "02144",
        address_country_code: "US"
      }
    )
    assert_equal [ existing.id ], exact.map(&:id)
    assert_includes exact.first.signals, "exact_postal_address"

    locality = FindSupplierLocationDuplicates.call(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      name: "Harbor Dock",
      address: { address_locality: "Somerville" }
    )
    assert_equal [ existing.id ], locality.map(&:id)
    assert_includes locality.first.signals, "name_and_locality"

    phone_only = FindSupplierLocationDuplicates.call(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      name: "Unrelated Pier",
      address: {}
    )
    assert_empty phone_only

    assert_raises(AgencyCommand::DuplicateReviewRequired) do
      create_location(
        supplier,
        name: "Copy Dock",
        address_line_1: "1 Dock St",
        address_locality: "Somerville",
        address_postal_code: "02144",
        address_country_code: "US"
      )
    end
  end

  test "contact duplicate email and phone stay within supplier" do
    supplier = create_supplier(display_name: "Contact Host", categories: [ "air" ]).record
    other_supplier = create_supplier(display_name: "Other Host", categories: [ "air" ]).record
    contact = create_contact(supplier, first_name: "Pat", last_name: "Guide").record
    CreateSupplierContactEmailAddress.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      supplier_contact: contact,
      attributes: { address: "pat@supplier.example" }
    ).call
    phone = PhoneNumberNormalizer.call(number: "202-555-0111", country_code: "US")
    CreateSupplierContactPhoneNumber.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      supplier_contact: contact,
      attributes: { number: phone.number, country_code: phone.country_code }
    ).call

    email_hits = FindSupplierContactDuplicates.call(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      first_name: nil,
      last_name: nil,
      emails: [ "pat@supplier.example" ]
    )
    assert_equal [ contact.id ], email_hits.map(&:id)
    assert_includes email_hits.first.signals, "exact_email"

    phone_hits = FindSupplierContactDuplicates.call(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      first_name: nil,
      last_name: nil,
      phones: [ phone ]
    )
    assert_equal [ contact.id ], phone_hits.map(&:id)
    assert_includes phone_hits.first.signals, "exact_phone"

    other_hits = FindSupplierContactDuplicates.call(
      agency: @agency,
      actor: @admin,
      supplier: other_supplier,
      first_name: nil,
      last_name: nil,
      emails: [ "pat@supplier.example" ]
    )
    assert_empty other_hits

    other_contact = create_contact(other_supplier, first_name: "Other", last_name: "Guide").record
    result = CreateSupplierContactEmailAddress.new(
      agency: @agency,
      actor: @admin,
      supplier: other_supplier,
      supplier_contact: other_contact,
      attributes: { address: "pat@supplier.example" }
    ).call
    assert_equal :created, result.status

    client_org = CreateClientOrganization.new(agency: @agency, actor: @admin, names: { display_name: "Client Email Org" }).call.record
    CreateClientOrganizationEmailAddress.new(
      agency: @agency,
      actor: @admin,
      client_organization: client_org,
      attributes: { address: "client-only@example.com" }
    ).call
    client_hits = FindSupplierContactDuplicates.call(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      first_name: nil,
      last_name: nil,
      emails: [ "client-only@example.com" ]
    )
    assert_empty client_hits
    client_create = CreateSupplierContactEmailAddress.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      supplier_contact: contact,
      attributes: { address: "client-only@example.com" }
    ).call
    assert_equal :created, client_create.status
  end

  test "create acknowledgement replay uses exact ownership chain and rejects partial chain" do
    supplier = create_supplier(display_name: "Replay Host", categories: [ "cruise_line" ]).record
    create_location(
      supplier,
      name: "Original Pier",
      address_line_1: "9 Replay Way",
      address_country_code: "US"
    )

    error = assert_raises(AgencyCommand::DuplicateReviewRequired) do
      create_location(
        supplier,
        name: "Replay Pier",
        address_line_1: "9 Replay Way",
        address_country_code: "US"
      )
    end

    created = create_location(
      supplier,
      name: "Replay Pier",
      address_line_1: "9 Replay Way",
      address_country_code: "US",
      acknowledgement_token: error.token,
      acknowledgement_reason: "confirmed_distinct"
    )
    replayed = create_location(
      supplier,
      name: "Replay Pier",
      address_line_1: "9 Replay Way",
      address_country_code: "US",
      acknowledgement_token: error.token,
      acknowledgement_reason: "confirmed_distinct"
    )

    assert_equal :created, created.status
    assert_equal :replayed, replayed.status
    assert_equal created.record, replayed.record
    assert_equal 1, AuditEvent.where(action: "supplier_location.created", subject_id: created.record.id).count
    assert_equal 1, AuditEvent.where(action: "supplier_location.duplicate_override", subject_id: created.record.id).count

    other_supplier = create_supplier(display_name: "Partial Host", categories: [ "lodging" ]).record
    create_location(
      other_supplier,
      name: "Partial Original",
      address_line_1: "3 Partial Rd",
      address_country_code: "US"
    )
    partial_error = assert_raises(AgencyCommand::DuplicateReviewRequired) do
      create_location(
        other_supplier,
        name: "Partial Copy",
        address_line_1: "3 Partial Rd",
        address_country_code: "US"
      )
    end
    payload = DuplicateAcknowledgement.verify!(
      partial_error.token,
      agency: @agency,
      actor: @admin,
      command: "CreateSupplierLocation"
    )
    @agency.supplier_locations.create!(
      id: payload.fetch("supplier_location_id"),
      agency: @agency,
      supplier: supplier,
      name: "Wrong Owner Pier",
      status: "active"
    )

    conflict = assert_raises(AgencyCommand::Error) do
      create_location(
        other_supplier,
        name: "Partial Copy",
        address_line_1: "3 Partial Rd",
        address_country_code: "US",
        acknowledgement_token: partial_error.token,
        acknowledgement_reason: "confirmed_distinct"
      )
    end
    assert_equal :conflict, conflict.code
  end

  test "preferred contact is exclusive zero preferred is valid and distinct from destination primary" do
    supplier = create_supplier(display_name: "Preferred Host", categories: [ "cruise_line" ]).record
    first = create_contact(supplier, first_name: "First", last_name: "Contact").record
    second = create_contact(supplier, first_name: "Second", last_name: "Contact").record
    assert_equal 0, supplier.contacts.where(preferred: true).count

    SetPreferredSupplierContact.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      supplier_contact: first,
      preferred: true,
      lock_version: first.lock_version
    ).call
    assert first.reload.preferred?
    assert_not second.reload.preferred?

    SetPreferredSupplierContact.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      supplier_contact: second.reload,
      preferred: true,
      lock_version: second.lock_version
    ).call
    assert second.reload.preferred?
    assert_not first.reload.preferred?

    email = CreateSupplierContactEmailAddress.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      supplier_contact: second,
      attributes: { address: "primary@example.com" }
    ).call.record
    SetPreferredSupplierContactEmailAddress.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      supplier_contact: second,
      record: email,
      lock_version: email.lock_version
    ).call

    assert email.reload.preferred?
    assert second.reload.preferred?

    SetPreferredSupplierContact.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      supplier_contact: second.reload,
      preferred: false,
      lock_version: second.lock_version
    ).call
    assert_not second.reload.preferred?
    assert email.reload.preferred?
    assert_equal 0, supplier.contacts.where(preferred: true).count
  end

  test "contact inactivation cascades destinations clears preferred and audits affected rows" do
    supplier = create_supplier(display_name: "Cascade Contact Host", categories: [ "air" ]).record
    contact = create_contact(supplier, first_name: "Cascade", last_name: "Contact").record
    SetPreferredSupplierContact.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      supplier_contact: contact,
      preferred: true,
      lock_version: contact.lock_version
    ).call
    email = CreateSupplierContactEmailAddress.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      supplier_contact: contact.reload,
      attributes: { address: "cascade@example.com", preferred: true }
    ).call.record
    phone = CreateSupplierContactPhoneNumber.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      supplier_contact: contact,
      attributes: { number: "202-555-0122", country_code: "US", preferred: true }
    ).call.record

    result = ChangeSupplierContactStatus.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      supplier_contact: contact.reload,
      status: "inactive",
      lock_version: contact.lock_version
    ).call

    assert_equal :updated, result.status
    assert_equal "inactive", contact.reload.status
    assert_not contact.preferred?
    assert_equal "inactive", email.reload.status
    assert_not email.preferred?
    assert_equal "inactive", phone.reload.status
    assert_not phone.preferred?

    audit = AuditEvent.where(action: "supplier_contact.inactivated", subject_id: contact.id).last
    assert_equal contact.id, audit.details["supplier_contact_id"]
    assert_equal %w[SupplierContactEmailAddress SupplierContactPhoneNumber],
      audit.details["inactivated_contact_destinations"].map { |row| row["type"] }.sort
    assert_equal [ email.id, phone.id ].sort,
      audit.details["inactivated_contact_destinations"].map { |row| row["id"] }.sort
    assert_not audit.details.to_json.include?("Cascade")
    assert_not audit.details.to_json.include?("cascade@example.com")
  end

  test "supplier inactivation cascades locations contacts destinations and restores none" do
    supplier = create_supplier(display_name: "Lifecycle Host", categories: [ "cruise_line" ]).record
    location = create_location(supplier, name: "Lifecycle Pier").record
    contact = create_contact(supplier, first_name: "Life", last_name: "Cycle").record
    SetPreferredSupplierContact.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      supplier_contact: contact,
      preferred: true,
      lock_version: contact.lock_version
    ).call
    supplier_email = CreateSupplierEmailAddress.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      attributes: { address: "life@example.com", preferred: true }
    ).call.record
    contact_email = CreateSupplierContactEmailAddress.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      supplier_contact: contact.reload,
      attributes: { address: "life-contact@example.com", preferred: true }
    ).call.record

    result = ChangeSupplierStatus.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      status: "inactive",
      lock_version: supplier.lock_version
    ).call

    assert_equal :updated, result.status
    assert_equal "inactive", location.reload.status
    assert_equal "inactive", contact.reload.status
    assert_not contact.preferred?
    assert_equal "inactive", supplier_email.reload.status
    assert_not supplier_email.preferred?
    assert_equal "inactive", contact_email.reload.status
    assert_not contact_email.preferred?

    audit = AuditEvent.where(action: "supplier.inactivated", subject_id: supplier.id).last
    assert_equal [ { "type" => "SupplierLocation", "id" => location.id } ], audit.details["inactivated_locations"]
    assert_equal [ { "type" => "SupplierContact", "id" => contact.id } ], audit.details["inactivated_contacts"]
    assert_equal [ { "type" => "SupplierEmailAddress", "id" => supplier_email.id } ], audit.details["inactivated_contact_points"]
    assert_equal [ { "type" => "SupplierContactEmailAddress", "id" => contact_email.id } ],
      audit.details["inactivated_contact_destinations"]

    ChangeSupplierStatus.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier.reload,
      status: "active",
      lock_version: supplier.lock_version
    ).call

    assert_equal "active", supplier.reload.status
    assert_equal "inactive", location.reload.status
    assert_equal "inactive", contact.reload.status
    assert_not contact.preferred?
    assert_equal "inactive", supplier_email.reload.status
    assert_equal "inactive", contact_email.reload.status
  end

  test "search returns discriminated location and contact results with permission and filter rules" do
    alpha = create_supplier(display_name: "Shared Port Alpha", categories: [ "cruise_line" ]).record
    beta = create_supplier(display_name: "Shared Port Beta", categories: [ "lodging" ]).record
    location = create_location(
      alpha,
      name: "Shared Port Desk",
      address_line_1: "100 Biscayne",
      address_locality: "Miami",
      address_postal_code: "33131",
      address_country_code: "US",
      phone_number: "305-555-0144",
      phone_country_code: "US"
    ).record
    miami_terminal = create_location(alpha, name: "Alpha Miami Terminal").record
    contact = create_contact(alpha, first_name: "Miami", last_name: "Agent").record
    CreateSupplierContactEmailAddress.new(
      agency: @agency,
      actor: @admin,
      supplier: alpha,
      supplier_contact: contact,
      attributes: { address: "miami.agent@example.com" }
    ).call
    inactive_location = create_location(beta, name: "Inactive Beta Desk").record
    ChangeSupplierLocationStatus.new(
      agency: @agency,
      actor: @admin,
      supplier: beta,
      supplier_location: inactive_location,
      status: "inactive",
      lock_version: inactive_location.lock_version
    ).call

    browse = SearchSupplierDirectory.call(agency: @agency, actor: @admin)
    assert browse.records.all? { |row| row.result_kind == "supplier" }
    assert_includes browse.records.map(&:id), alpha.id
    assert_not_includes browse.records.map(&:id), location.id

    mixed = SearchSupplierDirectory.call(agency: @agency, actor: @admin, query: "Shared Port")
    kinds = mixed.records.map { |row| [ row.result_kind, row.id ] }
    assert_includes kinds, [ "supplier", alpha.id ]
    assert_includes kinds, [ "supplier", beta.id ]
    assert_includes kinds, [ "location", location.id ]
    assert mixed.records.all? { |row| row.result_kind.present? && row.supplier_reference.present? }

    supplier_rows = mixed.records.select { |row| row.result_kind == "supplier" }
    assert_equal [ alpha.id, beta.id ], supplier_rows.map(&:id)
    alpha_index = mixed.records.index { |row| row.result_kind == "supplier" && row.id == alpha.id }
    location_index = mixed.records.index { |row| row.result_kind == "location" && row.id == location.id }
    assert_operator alpha_index, :<, location_index

    contact_match = SearchSupplierDirectory.call(agency: @agency, actor: @admin, query: "Miami Agent")
    assert_includes contact_match.records.map { |row| [ row.result_kind, row.id ] }, [ "contact", contact.id ]

    viewer_location = SearchSupplierDirectory.call(agency: @agency, actor: @viewer, query: "Alpha Miami Terminal")
    assert_equal [ [ "location", miami_terminal.id ] ], viewer_location.records.map { |row| [ row.result_kind, row.id ] }
    assert_empty SearchSupplierDirectory.call(agency: @agency, actor: @viewer, query: "Miami Agent").records
    assert_empty SearchSupplierDirectory.call(agency: @agency, actor: @viewer, query: "miami.agent@example.com").records
    assert_empty SearchSupplierDirectory.call(agency: @agency, actor: @viewer, query: "100 Biscayne").records
    assert_empty SearchSupplierDirectory.call(agency: @agency, actor: @admin, query: "305-555-0144").records

    assert_equal [ inactive_location.id ],
      SearchSupplierDirectory.call(agency: @agency, actor: @admin, query: "Inactive Beta Desk", status: "inactive")
        .records.select { |row| row.result_kind == "location" }.map(&:id)
    assert_equal [ miami_terminal.id ],
      SearchSupplierDirectory.call(agency: @agency, actor: @admin, query: "Alpha Miami", category: "cruise_line")
        .records.select { |row| row.result_kind == "location" }.map(&:id)
    assert_empty SearchSupplierDirectory.call(agency: @agency, actor: @admin, query: "Alpha Miami", category: "lodging")
      .records.select { |row| row.result_kind == "location" }
    assert_equal [ miami_terminal.id ],
      SearchSupplierDirectory.call(agency: @agency, actor: @admin, query: "Alpha Miami", kind: "organization")
        .records.select { |row| row.result_kind == "location" }.map(&:id)
  end

  test "cross-agency location and contact commands raise RecordNotFound" do
    harbor = create_supplier(display_name: "Harbor Scope", categories: [ "air" ]).record
    cove = create_supplier(agency: @other, actor: @other_admin, display_name: "Cove Scope", categories: [ "air" ]).record
    cove_location = CreateSupplierLocation.new(
      agency: @other,
      actor: @other_admin,
      supplier: cove,
      attributes: { name: "Cove Pier" }
    ).call.record
    cove_contact = CreateSupplierContact.new(
      agency: @other,
      actor: @other_admin,
      supplier: cove,
      attributes: { first_name: "Cove", last_name: "Guide" }
    ).call.record

    assert_raises ActiveRecord::RecordNotFound do
      UpdateSupplierLocation.new(
        agency: @agency,
        actor: @admin,
        supplier: harbor,
        supplier_location: cove_location,
        attributes: { name: "Hijacked" },
        lock_version: cove_location.lock_version
      ).call
    end
    assert_raises ActiveRecord::RecordNotFound do
      UpdateSupplierContact.new(
        agency: @agency,
        actor: @admin,
        supplier: harbor,
        supplier_contact: cove_contact,
        attributes: { first_name: "Hijacked", last_name: "Guide" },
        lock_version: cove_contact.lock_version
      ).call
    end
    assert_raises ActiveRecord::RecordNotFound do
      CreateSupplierLocation.new(
        agency: @agency,
        actor: @admin,
        supplier: cove,
        attributes: { name: "Wrong Tenant" }
      ).call
    end
  end

  test "stale lock_version conflicts for location and contact updates" do
    supplier = create_supplier(display_name: "Stale Host", categories: [ "air" ]).record
    location = create_location(supplier, name: "Stale Pier").record
    contact = create_contact(supplier, first_name: "Stale", last_name: "Contact").record

    location_error = assert_raises(AgencyCommand::Error) do
      UpdateSupplierLocation.new(
        agency: @agency,
        actor: @admin,
        supplier: supplier,
        supplier_location: location,
        attributes: { name: "Stale Pier Renamed" },
        lock_version: location.lock_version - 1
      ).call
    end
    assert_equal :conflict, location_error.code

    contact_error = assert_raises(AgencyCommand::Error) do
      UpdateSupplierContact.new(
        agency: @agency,
        actor: @admin,
        supplier: supplier,
        supplier_contact: contact,
        attributes: { first_name: "Stale", last_name: "Renamed" },
        lock_version: contact.lock_version - 1
      ).call
    end
    assert_equal :conflict, contact_error.code
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

  def create_location(supplier, acknowledgement_token: nil, acknowledgement_reason: nil, **attributes)
    CreateSupplierLocation.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      attributes: attributes,
      acknowledgement_token: acknowledgement_token,
      acknowledgement_reason: acknowledgement_reason
    ).call
  end

  def create_contact(supplier, acknowledgement_token: nil, acknowledgement_reason: nil, **attributes)
    CreateSupplierContact.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      attributes: attributes,
      acknowledgement_token: acknowledgement_token,
      acknowledgement_reason: acknowledgement_reason
    ).call
  end

  def ensure_supplier_sequence!(agency)
    agency.reference_sequences.find_or_create_by!(namespace: ReferenceSequence::SUPPLIER_NAMESPACE) do |sequence|
      sequence.next_value = 1
    end
  end

  def assert_raises_with_code(code, &block)
    error = assert_raises(AgencyCommand::Error, &block)
    assert_equal code, error.code
  end
end
