require "test_helper"

class M1DirectoryConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @scenario = M1DirectoryScenario.celebrity
    @agency = @scenario.agency
    @actor = @scenario.actor
  end

  teardown do
    M1DirectoryScenario.cleanup!(@agency)
  end

  test "parallel individual client creations issue distinct references" do
    outcomes = race(2) do |index|
      CreateIndividualClient.new(
        agency: Agency.find(@agency.id),
        actor: AgencyUser.find(@actor.id),
        names: { first_name: "Racer", last_name: "Client#{index}" }
      ).call
    end

    created = outcomes.select { |outcome| outcome.is_a?(AgencyCommand::Result) }
    assert_equal 2, created.size
    references = created.map { |result| result.record.client_reference }
    assert_equal 2, references.uniq.size
  end

  test "parallel client create-anyway token submissions replay without a second reference" do
    CreateIndividualClient.new(agency: @agency, actor: @actor, names: { first_name: "Token", last_name: "Twin" }).call
    error = assert_raises(AgencyCommand::DuplicateReviewRequired) do
      CreateIndividualClient.new(agency: @agency, actor: @actor, names: { first_name: "Token", last_name: "Twin" }).call
    end

    outcomes = race(2) do
      CreateIndividualClient.new(
        agency: Agency.find(@agency.id),
        actor: AgencyUser.find(@actor.id),
        names: { first_name: "Token", last_name: "Twin" },
        acknowledgement_token: error.token,
        acknowledgement_reason: "confirmed_distinct"
      ).call
    end

    results = outcomes.grep(AgencyCommand::Result)
    assert_equal %i[created replayed], results.map(&:status).sort
    assert_equal 1, results.map { |result| result.record.id }.uniq.size
    client = results.first.record
    assert_equal 1, AuditEvent.where(agency_id: @agency.id, action: "client.created", subject_id: client.id).count
    assert_equal 1, AuditEvent.where(agency_id: @agency.id, action: "client_person.duplicate_override", subject_id: client.client_person_id).count
  end

  test "a stale duplicate token cannot succeed after a concurrent create changes candidates" do
    CreateIndividualClient.new(agency: @agency, actor: @actor, names: { first_name: "Lane", last_name: "Duplicate" }).call
    first_review = assert_raises(AgencyCommand::DuplicateReviewRequired) do
      CreateIndividualClient.new(agency: @agency, actor: @actor, names: { first_name: "Lane", last_name: "Duplicate" }).call
    end
    second_review = assert_raises(AgencyCommand::DuplicateReviewRequired) do
      CreateIndividualClient.new(agency: @agency, actor: @actor, names: { first_name: "Lane", last_name: "Duplicate" }).call
    end

    outcomes = race(2) do |index|
      token = index.zero? ? first_review.token : second_review.token
      CreateIndividualClient.new(
        agency: Agency.find(@agency.id),
        actor: AgencyUser.find(@actor.id),
        names: { first_name: "Lane", last_name: "Duplicate" },
        acknowledgement_token: token,
        acknowledgement_reason: "confirmed_distinct"
      ).call
    end

    created = outcomes.grep(AgencyCommand::Result).select { |result| result.status == :created }
    failures = outcomes.reject { |outcome| outcome.is_a?(AgencyCommand::Result) }
    assert_equal 2, created.size + failures.size
    assert created.size >= 1
    people = @agency.client_people.where(first_name: "Lane", last_name: "Duplicate")
    assert_equal 1 + created.size, people.size
  end

  test "competing destination preference changes leave one preferred active destination per owner per channel" do
    DESTINATION_RACES.each do |definition|
      owner, points, command = instance_exec(&definition)
      outcomes = race(2) do |index|
        point = points[index].reload
        command.call(agency: Agency.find(@agency.id), actor: AgencyUser.find(@actor.id), owner:, point:)
      end

      preferred = points.map(&:reload).select(&:preferred?)
      assert_equal 1, preferred.size, "#{definition.source_location}: #{outcomes.map { |outcome| outcome.class.name }}"
    end
  end

  test "parallel CreateClientForPerson on one source leaves exactly one Client" do
    person = CreateClientPerson.new(agency: @agency, actor: @actor, names: { first_name: "Solo", last_name: "Source" }).call.record
    outcomes = race(2) do
      CreateClientForPerson.new(
        agency: Agency.find(@agency.id),
        actor: AgencyUser.find(@actor.id),
        client_person: ClientPerson.find(person.id)
      ).call
    end

    created = outcomes.grep(AgencyCommand::Result)
    errors = outcomes.grep(AgencyCommand::Error)
    assert_equal 1, created.size
    assert_equal :already_exists, errors.first.code
    assert_equal 1, Client.where(client_person_id: person.id).count
  end

  test "overlapping organization-contact assignments cannot both remain current" do
    organization = CreateClientOrganization.new(agency: @agency, actor: @actor, names: { display_name: "Overlap Org" }).call.record
    person = CreateClientPerson.new(agency: @agency, actor: @actor, names: { first_name: "Overlap", last_name: "Contact" }).call.record
    outcomes = race(2) do
      AddClientOrganizationContact.new(
        agency: Agency.find(@agency.id),
        actor: AgencyUser.find(@actor.id),
        client_organization: ClientOrganization.find(organization.id),
        client_person: ClientPerson.find(person.id),
        attributes: { starts_on: Date.new(2026, 1, 1) }
      ).call
    end

    created = outcomes.grep(AgencyCommand::Result)
    errors = outcomes.grep(AgencyCommand::Error)
    assert_equal 1, created.size
    assert_includes %i[invalid already_exists conflict], errors.first.code
    assert_equal 1, organization.organization_contacts.current.count
  end

  test "competing organization primary changes leave at most one current primary" do
    organization = CreateClientOrganization.new(agency: @agency, actor: @actor, names: { display_name: "Primary Org" }).call.record
    first = AddClientOrganizationContact.new(
      agency: @agency, actor: @actor, client_organization: organization,
      client_person: CreateClientPerson.new(agency: @agency, actor: @actor, names: { first_name: "One", last_name: "Primary" }).call.record,
      attributes: { starts_on: Date.new(2026, 1, 1) }
    ).call.record
    second = AddClientOrganizationContact.new(
      agency: @agency, actor: @actor, client_organization: organization,
      client_person: CreateClientPerson.new(agency: @agency, actor: @actor, names: { first_name: "Two", last_name: "Primary" }).call.record,
      attributes: { starts_on: Date.new(2026, 1, 1) }
    ).call.record

    race(2) do |index|
      assignment = index.zero? ? first : second
      ChangeClientOrganizationPrimaryContact.new(
        agency: Agency.find(@agency.id),
        actor: AgencyUser.find(@actor.id),
        client_organization_contact: ClientOrganizationContact.find(assignment.id),
        lock_version: assignment.lock_version
      ).call
    end

    primaries = organization.organization_contacts.current.where(primary: true)
    assert_equal 1, primaries.count
  end

  test "parallel supplier create-anyway token submissions replay without a second reference" do
    CreateSupplier.new(agency: @agency, actor: @actor, kind: "organization", names: { display_name: "Token Cruise" }, categories: [ "cruise_line" ]).call
    error = assert_raises(AgencyCommand::DuplicateReviewRequired) do
      CreateSupplier.new(agency: @agency, actor: @actor, kind: "organization", names: { display_name: "Token Cruise" }, categories: [ "cruise_line" ]).call
    end

    outcomes = race(2) do
      CreateSupplier.new(
        agency: Agency.find(@agency.id),
        actor: AgencyUser.find(@actor.id),
        kind: "organization",
        names: { display_name: "Token Cruise" },
        categories: [ "cruise_line" ],
        acknowledgement_token: error.token,
        acknowledgement_reason: "confirmed_distinct"
      ).call
    end

    results = outcomes.grep(AgencyCommand::Result)
    assert_equal %i[created replayed], results.map(&:status).sort
    assert_equal 1, results.map { |result| result.record.id }.uniq.size
  end

  test "parallel location create-anyway token submissions replay once" do
    supplier = CreateSupplier.new(agency: @agency, actor: @actor, kind: "organization", names: { display_name: "Token Port Host" }, categories: [ "air" ]).call.record
    CreateSupplierLocation.new(agency: @agency, actor: @actor, supplier:, attributes: { name: "Token Pier", address_line_1: "1 Token Way", address_locality: "Miami", address_postal_code: "33101", address_country_code: "US" }).call
    error = assert_raises(AgencyCommand::DuplicateReviewRequired) do
      CreateSupplierLocation.new(agency: @agency, actor: @actor, supplier:, attributes: { name: "Other Pier", address_line_1: "1 Token Way", address_locality: "Miami", address_postal_code: "33101", address_country_code: "US" }).call
    end

    outcomes = race(2) do
      CreateSupplierLocation.new(
        agency: Agency.find(@agency.id),
        actor: AgencyUser.find(@actor.id),
        supplier: Supplier.find(supplier.id),
        attributes: { name: "Other Pier", address_line_1: "1 Token Way", address_locality: "Miami", address_postal_code: "33101", address_country_code: "US" },
        acknowledgement_token: error.token,
        acknowledgement_reason: "confirmed_distinct"
      ).call
    end

    results = outcomes.grep(AgencyCommand::Result)
    assert_equal %i[created replayed], results.map(&:status).sort
    assert_equal 1, results.map { |result| result.record.id }.uniq.size
  end

  test "parallel supplier contact create-anyway token submissions replay once" do
    supplier = CreateSupplier.new(agency: @agency, actor: @actor, kind: "organization", names: { display_name: "Token Contact Host" }, categories: [ "air" ]).call.record
    CreateSupplierContact.new(agency: @agency, actor: @actor, supplier:, attributes: { first_name: "Token", last_name: "Contact" }).call
    error = assert_raises(AgencyCommand::DuplicateReviewRequired) do
      CreateSupplierContact.new(agency: @agency, actor: @actor, supplier:, attributes: { first_name: "Token", last_name: "Contact" }).call
    end

    outcomes = race(2) do
      CreateSupplierContact.new(
        agency: Agency.find(@agency.id),
        actor: AgencyUser.find(@actor.id),
        supplier: Supplier.find(supplier.id),
        attributes: { first_name: "Token", last_name: "Contact" },
        acknowledgement_token: error.token,
        acknowledgement_reason: "confirmed_distinct"
      ).call
    end

    results = outcomes.grep(AgencyCommand::Result)
    assert_equal %i[created replayed], results.map(&:status).sort
    assert_equal 1, results.map { |result| result.record.id }.uniq.size
  end

  test "supplier category mutation versus inactivation serializes without a lost mutation" do
    supplier = CreateSupplier.new(agency: @agency, actor: @actor, kind: "organization", names: { display_name: "Category Race" }, categories: [ "air" ]).call.record
    outcomes = race(2) do |index|
      current = Supplier.find(supplier.id)
      if index.zero?
        ReplaceSupplierCategories.new(
          agency: Agency.find(@agency.id),
          actor: AgencyUser.find(@actor.id),
          supplier: current,
          categories: [ "cruise_line" ],
          lock_version: current.lock_version
        ).call
      else
        ChangeSupplierStatus.new(
          agency: Agency.find(@agency.id),
          actor: AgencyUser.find(@actor.id),
          supplier: current,
          status: "inactive",
          lock_version: current.lock_version
        ).call
      end
    end

    results = outcomes.grep(AgencyCommand::Result)
    errors = outcomes.grep(AgencyCommand::Error)
    assert_equal 2, results.size + errors.size
    supplier.reload
    if supplier.inactive?
      codes = supplier.category_assignments.order(:category_code).pluck(:category_code)
      assert_includes [ [ "air" ], [ "cruise_line" ] ], codes
    else
      assert_equal [ "cruise_line" ], supplier.category_assignments.pluck(:category_code)
    end
  end

  test "competing preferred supplier contacts leave one preferred active contact" do
    supplier = CreateSupplier.new(agency: @agency, actor: @actor, kind: "organization", names: { display_name: "Preferred Host" }, categories: [ "air" ]).call.record
    first = CreateSupplierContact.new(agency: @agency, actor: @actor, supplier:, attributes: { first_name: "First", last_name: "Preferred" }).call.record
    second = CreateSupplierContact.new(agency: @agency, actor: @actor, supplier:, attributes: { first_name: "Second", last_name: "Preferred" }).call.record

    race(2) do |index|
      contact = index.zero? ? first : second
      SetPreferredSupplierContact.new(
        agency: Agency.find(@agency.id),
        actor: AgencyUser.find(@actor.id),
        supplier: Supplier.find(supplier.id),
        supplier_contact: SupplierContact.find(contact.id),
        preferred: true,
        lock_version: contact.lock_version
      ).call
    end

    assert_equal 1, supplier.contacts.where(preferred: true, status: "active").count
  end

  test "organization inactivation versus contact creation leaves no active child under an inactive organization" do
    organization = CreateOrganizationClient.new(agency: @agency, actor: @actor, names: { display_name: "Lifecycle Org" }).call.record.client_organization
    ChangeClientStatus.new(agency: @agency, actor: @actor, client: organization.client, status: "inactive", lock_version: organization.client.lock_version).call
    person = CreateClientPerson.new(agency: @agency, actor: @actor, names: { first_name: "Child", last_name: "Contact" }).call.record

    race(2) do |index|
      if index.zero?
        ChangeClientOrganizationStatus.new(
          agency: Agency.find(@agency.id),
          actor: AgencyUser.find(@actor.id),
          client_organization: ClientOrganization.find(organization.id),
          status: "inactive",
          lock_version: organization.lock_version
        ).call
      else
        AddClientOrganizationContact.new(
          agency: Agency.find(@agency.id),
          actor: AgencyUser.find(@actor.id),
          client_organization: ClientOrganization.find(organization.id),
          client_person: ClientPerson.find(person.id),
          attributes: { starts_on: Date.new(2026, 1, 1) }
        ).call
      end
    end

    organization.reload
    if organization.inactive?
      assert_equal 0, organization.organization_contacts.current.count
    end
  end

  test "contact inactivation versus destination reactivation leaves no active destination under an inactive contact" do
    supplier = CreateSupplier.new(agency: @agency, actor: @actor, kind: "organization", names: { display_name: "Destination Host" }, categories: [ "air" ]).call.record
    contact = CreateSupplierContact.new(agency: @agency, actor: @actor, supplier:, attributes: { first_name: "Active", last_name: "Desk" }).call.record
    point = CreateSupplierContactEmailAddress.new(
      agency: @agency, actor: @actor, supplier:, supplier_contact: contact, attributes: { address: "desk-#{@scenario.suffix}@example.test" }
    ).call.record
    ChangeSupplierContactEmailAddressStatus.new(
      agency: @agency, actor: @actor, supplier:, supplier_contact: contact, record: point, status: "inactive", lock_version: point.lock_version
    ).call
    point.reload

    race(2) do |index|
      if index.zero?
        ChangeSupplierContactStatus.new(
          agency: Agency.find(@agency.id),
          actor: AgencyUser.find(@actor.id),
          supplier: Supplier.find(supplier.id),
          supplier_contact: SupplierContact.find(contact.id),
          status: "inactive",
          lock_version: contact.lock_version
        ).call
      else
        ChangeSupplierContactEmailAddressStatus.new(
          agency: Agency.find(@agency.id),
          actor: AgencyUser.find(@actor.id),
          supplier: Supplier.find(supplier.id),
          supplier_contact: SupplierContact.find(contact.id),
          record: SupplierContactEmailAddress.find(point.id),
          status: "active",
          lock_version: point.lock_version
        ).call
      end
    end

    contact.reload
    point.reload
    assert_not(contact.inactive? && point.active?)
  end

  test "supplier inactivation versus location mutation leaves no active descendant under an inactive supplier" do
    supplier = CreateSupplier.new(agency: @agency, actor: @actor, kind: "organization", names: { display_name: "Cascade Host" }, categories: [ "air" ]).call.record
    location = CreateSupplierLocation.new(agency: @agency, actor: @actor, supplier:, attributes: { name: "Open Desk" }).call.record

    race(2) do |index|
      current = Supplier.find(supplier.id)
      if index.zero?
        ChangeSupplierStatus.new(
          agency: Agency.find(@agency.id),
          actor: AgencyUser.find(@actor.id),
          supplier: current,
          status: "inactive",
          lock_version: current.lock_version
        ).call
      else
        ChangeSupplierLocationStatus.new(
          agency: Agency.find(@agency.id),
          actor: AgencyUser.find(@actor.id),
          supplier: current,
          supplier_location: SupplierLocation.find(location.id),
          status: "inactive",
          lock_version: location.lock_version
        ).call
      end
    end

    supplier.reload
    location.reload
    assert_not(supplier.inactive? && location.active?)
  end

  private

  DESTINATION_RACES = [
    -> {
      person = CreateClientPerson.new(agency: @agency, actor: @actor, names: { first_name: "Pref", last_name: "Email" }).call.record
      points = [
        CreateClientPersonEmailAddress.new(agency: @agency, actor: @actor, client_person: person, attributes: { address: "one-#{@scenario.suffix}@example.test" }).call.record,
        CreateClientPersonEmailAddress.new(agency: @agency, actor: @actor, client_person: person, attributes: { address: "two-#{@scenario.suffix}@example.test" }).call.record
      ]
      command = ->(agency:, actor:, owner:, point:) {
        SetPreferredClientPersonEmailAddress.new(agency:, actor:, client_person: owner, record: point, lock_version: point.lock_version).call
      }
      [ person, points, command ]
    },
    -> {
      person = CreateClientPerson.new(agency: @agency, actor: @actor, names: { first_name: "Pref", last_name: "Phone" }).call.record
      points = [
        CreateClientPersonPhoneNumber.new(agency: @agency, actor: @actor, client_person: person, attributes: { number: "202-555-0101", country_code: "US" }).call.record,
        CreateClientPersonPhoneNumber.new(agency: @agency, actor: @actor, client_person: person, attributes: { number: "202-555-0102", country_code: "US" }).call.record
      ]
      command = ->(agency:, actor:, owner:, point:) {
        SetPreferredClientPersonPhoneNumber.new(agency:, actor:, client_person: owner, record: point, lock_version: point.lock_version).call
      }
      [ person, points, command ]
    },
    -> {
      person = CreateClientPerson.new(agency: @agency, actor: @actor, names: { first_name: "Pref", last_name: "Postal" }).call.record
      points = [
        CreateClientPersonPostalAddress.new(agency: @agency, actor: @actor, client_person: person, attributes: { line_1: "1 Pref St", locality: "Miami", postal_code: "33101", country_code: "US" }).call.record,
        CreateClientPersonPostalAddress.new(agency: @agency, actor: @actor, client_person: person, attributes: { line_1: "2 Pref St", locality: "Miami", postal_code: "33102", country_code: "US" }).call.record
      ]
      command = ->(agency:, actor:, owner:, point:) {
        SetPreferredClientPersonPostalAddress.new(agency:, actor:, client_person: owner, record: point, lock_version: point.lock_version).call
      }
      [ person, points, command ]
    },
    -> {
      organization = CreateClientOrganization.new(agency: @agency, actor: @actor, names: { display_name: "Pref Org Email" }).call.record
      points = [
        CreateClientOrganizationEmailAddress.new(agency: @agency, actor: @actor, client_organization: organization, attributes: { address: "org-one-#{@scenario.suffix}@example.test" }).call.record,
        CreateClientOrganizationEmailAddress.new(agency: @agency, actor: @actor, client_organization: organization, attributes: { address: "org-two-#{@scenario.suffix}@example.test" }).call.record
      ]
      command = ->(agency:, actor:, owner:, point:) {
        SetPreferredClientOrganizationEmailAddress.new(agency:, actor:, client_organization: owner, record: point, lock_version: point.lock_version).call
      }
      [ organization, points, command ]
    },
    -> {
      organization = CreateClientOrganization.new(agency: @agency, actor: @actor, names: { display_name: "Pref Org Phone" }).call.record
      points = [
        CreateClientOrganizationPhoneNumber.new(agency: @agency, actor: @actor, client_organization: organization, attributes: { number: "202-555-0201", country_code: "US" }).call.record,
        CreateClientOrganizationPhoneNumber.new(agency: @agency, actor: @actor, client_organization: organization, attributes: { number: "202-555-0202", country_code: "US" }).call.record
      ]
      command = ->(agency:, actor:, owner:, point:) {
        SetPreferredClientOrganizationPhoneNumber.new(agency:, actor:, client_organization: owner, record: point, lock_version: point.lock_version).call
      }
      [ organization, points, command ]
    },
    -> {
      organization = CreateClientOrganization.new(agency: @agency, actor: @actor, names: { display_name: "Pref Org Postal" }).call.record
      points = [
        CreateClientOrganizationPostalAddress.new(agency: @agency, actor: @actor, client_organization: organization, attributes: { line_1: "10 Org St", locality: "Boston", postal_code: "02108", country_code: "US" }).call.record,
        CreateClientOrganizationPostalAddress.new(agency: @agency, actor: @actor, client_organization: organization, attributes: { line_1: "11 Org St", locality: "Boston", postal_code: "02109", country_code: "US" }).call.record
      ]
      command = ->(agency:, actor:, owner:, point:) {
        SetPreferredClientOrganizationPostalAddress.new(agency:, actor:, client_organization: owner, record: point, lock_version: point.lock_version).call
      }
      [ organization, points, command ]
    },
    -> {
      organization = CreateClientOrganization.new(agency: @agency, actor: @actor, names: { display_name: "Pref Org Web" }).call.record
      points = [
        CreateClientOrganizationWebsite.new(agency: @agency, actor: @actor, client_organization: organization, attributes: { url: "https://one-#{@scenario.suffix}.example" }).call.record,
        CreateClientOrganizationWebsite.new(agency: @agency, actor: @actor, client_organization: organization, attributes: { url: "https://two-#{@scenario.suffix}.example" }).call.record
      ]
      command = ->(agency:, actor:, owner:, point:) {
        SetPreferredClientOrganizationWebsite.new(agency:, actor:, client_organization: owner, record: point, lock_version: point.lock_version).call
      }
      [ organization, points, command ]
    },
    -> {
      supplier = CreateSupplier.new(agency: @agency, actor: @actor, kind: "organization", names: { display_name: "Pref Sup Email" }, categories: [ "air" ]).call.record
      points = [
        CreateSupplierEmailAddress.new(agency: @agency, actor: @actor, supplier:, attributes: { address: "sup-one-#{@scenario.suffix}@example.test" }).call.record,
        CreateSupplierEmailAddress.new(agency: @agency, actor: @actor, supplier:, attributes: { address: "sup-two-#{@scenario.suffix}@example.test" }).call.record
      ]
      command = ->(agency:, actor:, owner:, point:) {
        SetPreferredSupplierEmailAddress.new(agency:, actor:, supplier: owner, record: point, lock_version: point.lock_version).call
      }
      [ supplier, points, command ]
    },
    -> {
      supplier = CreateSupplier.new(agency: @agency, actor: @actor, kind: "organization", names: { display_name: "Pref Sup Phone" }, categories: [ "air" ]).call.record
      points = [
        CreateSupplierPhoneNumber.new(agency: @agency, actor: @actor, supplier:, attributes: { number: "202-555-0301", country_code: "US" }).call.record,
        CreateSupplierPhoneNumber.new(agency: @agency, actor: @actor, supplier:, attributes: { number: "202-555-0302", country_code: "US" }).call.record
      ]
      command = ->(agency:, actor:, owner:, point:) {
        SetPreferredSupplierPhoneNumber.new(agency:, actor:, supplier: owner, record: point, lock_version: point.lock_version).call
      }
      [ supplier, points, command ]
    },
    -> {
      supplier = CreateSupplier.new(agency: @agency, actor: @actor, kind: "organization", names: { display_name: "Pref Sup Postal" }, categories: [ "air" ]).call.record
      points = [
        CreateSupplierPostalAddress.new(agency: @agency, actor: @actor, supplier:, attributes: { line_1: "20 Sup St", locality: "Miami", postal_code: "33131", country_code: "US" }).call.record,
        CreateSupplierPostalAddress.new(agency: @agency, actor: @actor, supplier:, attributes: { line_1: "21 Sup St", locality: "Miami", postal_code: "33132", country_code: "US" }).call.record
      ]
      command = ->(agency:, actor:, owner:, point:) {
        SetPreferredSupplierPostalAddress.new(agency:, actor:, supplier: owner, record: point, lock_version: point.lock_version).call
      }
      [ supplier, points, command ]
    },
    -> {
      supplier = CreateSupplier.new(agency: @agency, actor: @actor, kind: "organization", names: { display_name: "Pref Sup Web" }, categories: [ "air" ]).call.record
      points = [
        CreateSupplierWebsite.new(agency: @agency, actor: @actor, supplier:, attributes: { url: "https://sup-one-#{@scenario.suffix}.example" }).call.record,
        CreateSupplierWebsite.new(agency: @agency, actor: @actor, supplier:, attributes: { url: "https://sup-two-#{@scenario.suffix}.example" }).call.record
      ]
      command = ->(agency:, actor:, owner:, point:) {
        SetPreferredSupplierWebsite.new(agency:, actor:, supplier: owner, record: point, lock_version: point.lock_version).call
      }
      [ supplier, points, command ]
    },
    -> {
      supplier = CreateSupplier.new(agency: @agency, actor: @actor, kind: "organization", names: { display_name: "Pref Contact Dest" }, categories: [ "air" ]).call.record
      contact = CreateSupplierContact.new(agency: @agency, actor: @actor, supplier:, attributes: { first_name: "Pref", last_name: "Dest" }).call.record
      points = [
        CreateSupplierContactEmailAddress.new(agency: @agency, actor: @actor, supplier:, supplier_contact: contact, attributes: { address: "c-one-#{@scenario.suffix}@example.test" }).call.record,
        CreateSupplierContactEmailAddress.new(agency: @agency, actor: @actor, supplier:, supplier_contact: contact, attributes: { address: "c-two-#{@scenario.suffix}@example.test" }).call.record
      ]
      command = ->(agency:, actor:, owner:, point:) {
        SetPreferredSupplierContactEmailAddress.new(agency:, actor:, supplier: owner, supplier_contact: contact, record: point, lock_version: point.lock_version).call
      }
      [ supplier, points, command ]
    },
    -> {
      supplier = CreateSupplier.new(agency: @agency, actor: @actor, kind: "organization", names: { display_name: "Pref Contact Phone" }, categories: [ "air" ]).call.record
      contact = CreateSupplierContact.new(agency: @agency, actor: @actor, supplier:, attributes: { first_name: "Pref", last_name: "Phone" }).call.record
      points = [
        CreateSupplierContactPhoneNumber.new(agency: @agency, actor: @actor, supplier:, supplier_contact: contact, attributes: { number: "202-555-0401", country_code: "US" }).call.record,
        CreateSupplierContactPhoneNumber.new(agency: @agency, actor: @actor, supplier:, supplier_contact: contact, attributes: { number: "202-555-0402", country_code: "US" }).call.record
      ]
      command = ->(agency:, actor:, owner:, point:) {
        SetPreferredSupplierContactPhoneNumber.new(agency:, actor:, supplier: owner, supplier_contact: contact, record: point, lock_version: point.lock_version).call
      }
      [ supplier, points, command ]
    }
  ].freeze

  def race(count)
    started = Queue.new
    threads = count.times.map do |index|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          started.pop
          yield index
        end
      rescue StandardError => error
        error
      end
    end
    count.times { started << true }
    threads.map(&:value)
  end
end
