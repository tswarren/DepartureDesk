module M1DirectoryScenario
  PASSWORD = "password12345"
  Result = Data.define(
    :suffix,
    :agency,
    :actor,
    :viewer,
    :martha,
    :martha_client,
    :martha_email,
    :daniel,
    :emily,
    :agency_user_person,
    :celebrity,
    :miami,
    :everglades,
    :preferred_contact,
    :shared_email_contact,
    :olivia,
    :olivia_client,
    :noah,
    :westlake,
    :westlake_client,
    :current_westlake_contact,
    :historical_westlake_contact,
    :vineyard_dmc,
    :motorcoach
  )

  def self.celebrity(suffix: unique_suffix)
    agency, actor, viewer = provision_agency!("Celebrity Directory", "c#{suffix}", suffix)
    martha_client = CreateIndividualClient.new(
      agency:, actor:, names: { first_name: "Martha", last_name: "Smith" }
    ).call.record
    martha = martha_client.client_person
    shared_email = "martha-#{suffix}@example.test"
    martha_email = CreateClientPersonEmailAddress.new(
      agency:, actor:, client_person: martha, attributes: { address: shared_email, preferred: true }
    ).call.record
    CreateClientPersonPhoneNumber.new(
      agency:, actor:, client_person: martha,
      attributes: { number: "305-555-0101", country_code: "US", preferred: true }
    ).call
    daniel = CreateClientPerson.new(agency:, actor:, names: { first_name: "Daniel", last_name: "Smith" }).call.record
    emily = CreateClientPerson.new(agency:, actor:, names: { first_name: "Emily", last_name: "Smith" }).call.record
    agency_user_person = CreateClientPerson.new(
      agency:, actor:, names: { first_name: actor.first_name, last_name: actor.last_name }
    ).call.record

    celebrity = CreateSupplier.new(
      agency:, actor:, kind: "organization",
      names: { display_name: "Celebrity Cruises" },
      categories: [ "cruise_line" ]
    ).call.record
    miami = CreateSupplierLocation.new(
      agency:, actor:, supplier: celebrity,
      attributes: {
        name: "Port of Miami",
        timezone: "America/New_York",
        address_line_1: "1015 N America Way",
        address_locality: "Miami",
        address_region: "FL",
        address_postal_code: "33132",
        address_country_code: "US"
      }
    ).call.record
    everglades = CreateSupplierLocation.new(
      agency:, actor:, supplier: celebrity,
      attributes: {
        name: "Port Everglades",
        timezone: "America/New_York",
        address_line_1: "1850 Eller Dr",
        address_locality: "Fort Lauderdale",
        address_region: "FL",
        address_postal_code: "33316",
        address_country_code: "US"
      }
    ).call.record

    preferred_contact = CreateSupplierContact.new(
      agency:, actor:, supplier: celebrity,
      attributes: { first_name: "Alex", last_name: "Purser", title: "Purser" }
    ).call.record
    CreateSupplierContactEmailAddress.new(
      agency:, actor:, supplier: celebrity, supplier_contact: preferred_contact,
      attributes: { address: "alex-#{suffix}@celebrity.example", preferred: true }
    ).call
    CreateSupplierContactPhoneNumber.new(
      agency:, actor:, supplier: celebrity, supplier_contact: preferred_contact,
      attributes: { number: "305-555-0199", country_code: "US", preferred: true }
    ).call
    SetPreferredSupplierContact.new(
      agency:, actor:, supplier: celebrity, supplier_contact: preferred_contact,
      preferred: true, lock_version: preferred_contact.lock_version
    ).call

    shared_email_contact = CreateSupplierContact.new(
      agency:, actor:, supplier: celebrity,
      attributes: { first_name: "Jordan", last_name: "Hotel", title: "Hotel director" }
    ).call.record
    CreateSupplierContactEmailAddress.new(
      agency:, actor:, supplier: celebrity, supplier_contact: shared_email_contact,
      attributes: { address: shared_email, preferred: true }
    ).call

    Result.new(
      suffix:, agency:, actor:, viewer:,
      martha:, martha_client:, martha_email:, daniel:, emily:, agency_user_person:,
      celebrity:, miami:, everglades:, preferred_contact:, shared_email_contact:,
      olivia: nil, olivia_client: nil, noah: nil, westlake: nil, westlake_client: nil,
      current_westlake_contact: nil, historical_westlake_contact: nil,
      vineyard_dmc: nil, motorcoach: nil
    )
  end

  def self.vineyard(suffix: unique_suffix)
    agency, actor, viewer = provision_agency!("Vineyard Directory", "v#{suffix}", suffix)
    olivia_client = CreateIndividualClient.new(
      agency:, actor:, names: { first_name: "Olivia", last_name: "Brown" }
    ).call.record
    olivia = olivia_client.client_person
    noah = CreateClientPerson.new(agency:, actor:, names: { first_name: "Noah", last_name: "Brown" }).call.record
    westlake_client = CreateOrganizationClient.new(
      agency:, actor:, names: { display_name: "Westlake Foods", legal_name: "Westlake Foods LLC" }
    ).call.record
    westlake = westlake_client.client_organization
    historical_westlake_contact = AddClientOrganizationContact.new(
      agency:, actor:, client_organization: westlake, client_person: noah,
      attributes: { starts_on: Date.new(2025, 1, 1), ends_on: Date.new(2025, 12, 31), title: "Buyer" }
    ).call.record
    current_westlake_contact = AddClientOrganizationContact.new(
      agency:, actor:, client_organization: westlake, client_person: olivia,
      attributes: { starts_on: Date.new(2026, 1, 1), primary: true, title: "Travel coordinator" }
    ).call.record
    vineyard_dmc = CreateSupplier.new(
      agency:, actor:, kind: "organization",
      names: { display_name: "Vineyard Tour DMC" },
      categories: [ "tour_operator_dmc" ]
    ).call.record
    motorcoach = CreateSupplier.new(
      agency:, actor:, kind: "organization",
      names: { display_name: "Valley Motorcoach" },
      categories: [ "ground_transportation" ]
    ).call.record

    Result.new(
      suffix:, agency:, actor:, viewer:,
      martha: nil, martha_client: nil, martha_email: nil, daniel: nil, emily: nil, agency_user_person: nil,
      celebrity: nil, miami: nil, everglades: nil, preferred_contact: nil, shared_email_contact: nil,
      olivia:, olivia_client:, noah:, westlake:, westlake_client:,
      current_westlake_contact:, historical_westlake_contact:, vineyard_dmc:, motorcoach:
    )
  end

  def self.empty(suffix: unique_suffix)
    agency, actor, viewer = provision_agency!("Empty Directory", "e#{suffix}", suffix)
    Result.new(
      suffix:, agency:, actor:, viewer:,
      martha: nil, martha_client: nil, martha_email: nil, daniel: nil, emily: nil, agency_user_person: nil,
      celebrity: nil, miami: nil, everglades: nil, preferred_contact: nil, shared_email_contact: nil,
      olivia: nil, olivia_client: nil, noah: nil, westlake: nil, westlake_client: nil,
      current_westlake_contact: nil, historical_westlake_contact: nil,
      vineyard_dmc: nil, motorcoach: nil
    )
  end

  def self.isolation_companion(primary)
    suffix = unique_suffix
    agency, actor, viewer = provision_agency!("Isolation Directory", "i#{suffix}", suffix)
    overlapping_email = primary.martha_email.address
    person = CreateIndividualClient.new(
      agency:, actor:, names: { first_name: "Martha", last_name: "Smith" }
    ).call.record.client_person
    CreateClientPersonEmailAddress.new(
      agency:, actor:, client_person: person, attributes: { address: overlapping_email }
    ).call
    CreateSupplier.new(
      agency:, actor:, kind: "organization",
      names: { display_name: "Celebrity Cruises" },
      categories: [ "cruise_line" ]
    ).call

    Result.new(
      suffix:, agency:, actor:, viewer:,
      martha: person, martha_client: person.client, martha_email: person.email_addresses.first,
      daniel: nil, emily: nil, agency_user_person: nil,
      celebrity: agency.suppliers.find_by!(display_name: "Celebrity Cruises"),
      miami: nil, everglades: nil, preferred_contact: nil, shared_email_contact: nil,
      olivia: nil, olivia_client: nil, noah: nil, westlake: nil, westlake_client: nil,
      current_westlake_contact: nil, historical_westlake_contact: nil,
      vineyard_dmc: nil, motorcoach: nil
    )
  end

  def self.cleanup!(*agencies)
    agencies.flatten.compact.uniq.each { |agency| delete_agency!(agency) }
  end

  def self.unique_suffix
    SecureRandom.hex(4)
  end

  def self.provision_agency!(name, workspace_code, suffix)
    agency = ProvisionAgency.new(
      name: "#{name} #{suffix}",
      workspace_code: workspace_code,
      country_code: "US",
      default_currency: "USD",
      default_timezone: "UTC",
      office_name: "Main Office",
      office_code: "MAIN",
      office_timezone: "UTC",
      administrator_email: "admin-#{suffix}@example.test",
      administrator_first_name: "Pat",
      administrator_last_name: "Harbor",
      administrator_password: PASSWORD,
      actor_identifier: "test:m1e-#{suffix}"
    ).call.record
    actor = agency.agency_users.sole
    viewer = agency.agency_users.create!(
      email_address: "viewer-#{suffix}@example.test",
      first_name: "Vera",
      last_name: "Viewer",
      password: PASSWORD,
      access_role: "viewer",
      status: "active",
      default_office: agency.offices.sole,
      credential_version: 1
    )
    [ agency, actor, viewer ]
  end
  private_class_method :provision_agency!

  def self.delete_agency!(agency)
    Agency.transaction do
      ActiveRecord::Base.connection.execute("SET LOCAL session_replication_role = replica")
      agency_id = agency.id
      user_ids = AgencyUser.where(agency_id:).pluck(:id)
      SupplierContactEmailAddress.where(agency_id:).delete_all
      SupplierContactPhoneNumber.where(agency_id:).delete_all
      SupplierContact.where(agency_id:).delete_all
      SupplierLocation.where(agency_id:).delete_all
      SupplierWebsite.where(agency_id:).delete_all
      SupplierPostalAddress.where(agency_id:).delete_all
      SupplierPhoneNumber.where(agency_id:).delete_all
      SupplierEmailAddress.where(agency_id:).delete_all
      SupplierCategoryAssignment.where(agency_id:).delete_all
      SupplierCostComponentBase.where(agency_id:).delete_all
      SupplierCostComponent.where(agency_id:).delete_all
      SupplierCostDefinition.where(agency_id:).delete_all
      SupplierCostOccupancyProfilePosition.where(agency_id:).delete_all
      SupplierCostOccupancyProfile.where(agency_id:).delete_all
      SupplierCostUsageAssumption.where(agency_id:).delete_all
      SupplierCostParticipantCategory.where(agency_id:).delete_all
      SupplierCostSource.where(agency_id:).delete_all
      Supplier.where(agency_id:).delete_all
      Departure.where(agency_id:).delete_all
      ClientOrganizationContact.where(agency_id:).delete_all
      ClientOrganizationWebsite.where(agency_id:).delete_all
      ClientOrganizationPostalAddress.where(agency_id:).delete_all
      ClientOrganizationPhoneNumber.where(agency_id:).delete_all
      ClientOrganizationEmailAddress.where(agency_id:).delete_all
      ClientPersonEmailAddress.where(agency_id:).delete_all
      ClientPersonPhoneNumber.where(agency_id:).delete_all
      ClientPersonPostalAddress.where(agency_id:).delete_all
      Client.where(agency_id:).delete_all
      ClientOrganization.where(agency_id:).delete_all
      ClientPerson.where(agency_id:).delete_all
      ReferenceSequence.where(agency_id:).delete_all
      AuditEvent.where(agency_id:).delete_all
      Session.where(agency_user_id: user_ids).delete_all
      AgencyUser.where(id: user_ids).delete_all
      Office.where(agency_id:).delete_all
      Agency.where(id: agency_id).delete_all
    end
  end
  private_class_method :delete_agency!
end
