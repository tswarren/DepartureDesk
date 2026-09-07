if Rails.env.development?
    seed_user = User.find_or_initialize_by(
      email_address: "email@example.com"
    )

    seed_user.assign_attributes(
      first_name: "Alex",
      last_name: "Mariner",
      password: "ChangeMe123!",
      password_confirmation: "ChangeMe123!"
    )

    seed_user.save!

    membership = seed_user.active_agency_memberships.includes(:agency).first

    if membership
      seed_agency = membership.agency
    else
      seed_agency = Agency.find_or_initialize_by(name: "Harbor Travel")
      seed_agency.assign_attributes(
        default_timezone: "UTC",
        default_currency: "USD",
        country_code: "US",
        status: "active"
      )
      seed_agency.save!

      membership = AgencyMembership.find_or_initialize_by(
        user: seed_user,
        agency: seed_agency
      )
      membership.assign_attributes(
        role: "administrator",
        status: "active"
      )
    end

    if membership.person_party_id.blank?
      person = LinkMembershipPerson.allocate_person(
        agency: seed_agency,
        given_name: seed_user.first_name,
        family_name: seed_user.last_name,
        actor_identifier: "seed:development",
        privileged: true
      )
      membership.person_party = person
    end

    membership.save!

    if membership.saved_change_to_person_party_id?
      LinkMembershipPerson.record_locked!(
        agency: seed_agency,
        membership: membership,
        person: membership.person_party,
        source: "seed",
        actor_identifier: "seed:development",
        privileged: true
      )
    end

    puts "Seed agency ready:"
    puts "  Name: #{seed_agency.name}"
    puts "  ID: #{seed_agency.id}"
    puts "Seed user ready:"
    puts "  Email: #{seed_user.email_address}"
    puts "  ID: #{seed_user.id}"
    office = seed_agency.offices.find_or_initialize_by(code: "MAIN")
    office.assign_attributes(
      name: seed_agency.name,
      status: "active",
      default_timezone: seed_agency.default_timezone
    )
    office.save!

    assignment = OfficeAssignment.find_or_initialize_by(
      agency: seed_agency,
      agency_membership: membership,
      office: office
    )
    assignment.assign_attributes(
      status: "active",
      is_default: true,
      granted_at: assignment.granted_at || Time.current,
      revoked_at: nil
    )
    assignment.save!

    puts "Seed membership ready:"
    puts "  ID: #{membership.id}"
    puts "  Role: #{membership.role}"
    puts "  Status: #{membership.status}"
    puts "Seed office ready:"
    puts "  Code: #{office.code}"
    puts "  ID: #{office.id}"

    demo_person = seed_agency.parties.find_by(display_name: "Alex Morgan")
    unless demo_person
      demo_person = CreateParty.new(
        agency: seed_agency,
        party_kind: "person",
        attributes: { given_name: "Alex", family_name: "Morgan" },
        actor_identifier: "seed:development",
        privileged: true
      ).call.party
    end
    demo_household = seed_agency.parties.find_by(display_name: "Morgan Household")
    unless demo_household
      demo_household = CreateParty.new(
        agency: seed_agency,
        party_kind: "household",
        attributes: { name: "Morgan Household" },
        actor_identifier: "seed:development",
        privileged: true
      ).call.party
    end
    unless demo_person.contact_points.email.any?
      CreatePartyContactPoint.new(
        agency: seed_agency,
        party: demo_person,
        contact_kind: "email",
        attributes: { display_address: "alex.directory@example.test", email_type: "personal" },
        actor_identifier: "seed:development",
        privileged: true
      ).call
    end
    unless PartyRelationship.involving(demo_person).exists?(relationship_kind: "household_member")
      CreatePartyRelationship.new(
        agency: seed_agency,
        origin_party: demo_person,
        related_party: demo_household,
        relationship_kind: "household_member",
        actor_identifier: "seed:development",
        privileged: true
      ).call
    end
    unless demo_person.notes.exists?
      CreatePartyNote.new(
        agency: seed_agency,
        party: demo_person,
        body: "Prefers morning calls for trip updates.",
        visibility: "standard",
        actor_identifier: "seed:development",
        privileged: true
      ).call
    end
    demo_organization = seed_agency.parties.find_by(display_name: "Horizon Tours")
    unless demo_organization
      demo_organization = CreateParty.new(
        agency: seed_agency,
        party_kind: "organization",
        attributes: { legal_name: "Horizon Tours" },
        actor_identifier: "seed:development",
        privileged: true
      ).call.party
    end
    unless demo_organization.client_profile
      CreateClientProfile.new(
        agency: seed_agency,
        party: demo_organization,
        office: office,
        actor_identifier: "seed:development",
        privileged: true
      ).call
    end
    unless demo_organization.supplier_profile
      CreateSupplierProfile.new(
        agency: seed_agency,
        party: demo_organization,
        office: office,
        actor_identifier: "seed:development",
        privileged: true
      ).call
    end
    unless demo_person.client_profile
      CreateClientProfile.new(
        agency: seed_agency,
        party: demo_person,
        office: office,
        actor_identifier: "seed:development",
        privileged: true
      ).call
    end
    puts "Seed directory demo ready:"
    puts "  Person: #{demo_person.display_name} (#{demo_person.id})"
    puts "  Household: #{demo_household.display_name} (#{demo_household.id})"
    puts "  Organization: #{demo_organization.display_name} (#{demo_organization.id})"

    seed_actor = { actor: seed_user }
    oceanview = seed_agency.parties.find_by(display_name: "OceanView Cruises")
    unless oceanview
      oceanview = CreateParty.new(
        agency: seed_agency,
        party_kind: "organization",
        attributes: { legal_name: "OceanView Cruises Limited", trading_name: "OceanView Cruises", website: "https://oceanview.example.test" },
        actor_identifier: "seed:development",
        privileged: true
      ).call.party
    end
    unless oceanview.alternate_names.visible.exists?(name: "OVC")
      AddPartyAlternateName.new(
        agency: seed_agency,
        party: oceanview,
        name: "OVC",
        name_kind: "acronym",
        **seed_actor
      ).call
    end
    unless oceanview.supplier_profile
      CreateSupplierProfile.new(
        agency: seed_agency,
        party: oceanview,
        office: office,
        actor_identifier: "seed:development",
        privileged: true
      ).call
    end
    oceanview.reload
    %w[cruise accommodation].each do |code|
      next if oceanview.supplier_profile.reload.category_codes.include?(code)

      AssignSupplierServiceCategory.new(
        agency: seed_agency,
        party: oceanview,
        profile: oceanview.supplier_profile,
        category_code: code,
        **seed_actor
      ).call
    end
    unless oceanview.contact_points.email.exists?
      general_email = CreatePartyContactPoint.new(
        agency: seed_agency,
        party: oceanview,
        contact_kind: "email",
        attributes: { display_address: "groups@oceanview.example.test", email_type: "work" },
        **seed_actor
      ).call.contact_point
      SetContactPointPrimary.new(
        agency: seed_agency,
        party: oceanview,
        contact_point: general_email,
        purpose: "general",
        **seed_actor
      ).call
    end
    unless oceanview.contact_points.phone.exists?
      CreatePartyContactPoint.new(
        agency: seed_agency,
        party: oceanview,
        contact_kind: "phone",
        attributes: { display_number: "206-555-0140", phone_type: "work", parsed_country_code: "US" },
        **seed_actor
      ).call
    end
    unless oceanview.contact_points.postal_address.exists?
      CreatePartyContactPoint.new(
        agency: seed_agency,
        party: oceanview,
        contact_kind: "postal_address",
        attributes: {
          address_line_1: "400 Harbor Avenue",
          locality: "Seattle",
          administrative_region: "WA",
          postal_code: "98104",
          country_code: "US"
        },
        **seed_actor
      ).call
    end
    billing_email = oceanview.contact_points.email.find_by(normalized_value: "billing@oceanview.example.test")
    unless billing_email
      billing_email = CreatePartyContactPoint.new(
        agency: seed_agency,
        party: oceanview,
        contact_kind: "email",
        attributes: { display_address: "billing@oceanview.example.test", email_type: "work" },
        **seed_actor
      ).call.contact_point
    end
    unless ContactPointPurposeAssignment.current_on(DirectoryDate.today(seed_agency)).exists?(contact_point: billing_email, purpose: "billing", priority: 1)
      SetContactPointPrimary.new(
        agency: seed_agency,
        party: oceanview,
        contact_point: billing_email,
        purpose: "billing",
        **seed_actor
      ).call
    end
    unless billing_email.reload.suppressed?
      SuppressPartyContactPoint.new(
        agency: seed_agency,
        party: oceanview,
        contact_point: billing_email,
        reason: "Accounts payable mailbox retired",
        **seed_actor
      ).call
    end
    unless oceanview.directory_external_identifiers.exists?(identifier_type: "supplier_account_number")
      AddExternalIdentifier.new(
        agency: seed_agency,
        party: oceanview,
        identifier_type: "supplier_account_number",
        original_value: "OVC-44019",
        issuer: "OceanView",
        **seed_actor
      ).call
    end
    unless oceanview.directory_external_identifiers.exists?(identifier_type: "supplier_portal_id")
      AddExternalIdentifier.new(
        agency: seed_agency,
        party: oceanview,
        identifier_type: "supplier_portal_id",
        original_value: "portal-ovc",
        issuer: "OceanView",
        **seed_actor
      ).call
    end
    booking_contact = seed_agency.parties.find_by(display_name: "Priya Shah")
    unless booking_contact
      booking_contact = CreateParty.new(
        agency: seed_agency,
        party_kind: "person",
        attributes: { given_name: "Priya", family_name: "Shah" },
        actor_identifier: "seed:development",
        privileged: true
      ).call.party
    end
    accounting_contact = seed_agency.parties.find_by(display_name: "Noah Ellis")
    unless accounting_contact
      accounting_contact = CreateParty.new(
        agency: seed_agency,
        party_kind: "person",
        attributes: { given_name: "Noah", family_name: "Ellis" },
        actor_identifier: "seed:development",
        privileged: true
      ).call.party
    end
    unless PartyRelationship.involving(oceanview).exists?(relationship_kind: "organization_contact", origin_party_id: booking_contact.id)
      CreatePartyRelationship.new(
        agency: seed_agency,
        origin_party: booking_contact,
        related_party: oceanview,
        relationship_kind: "organization_contact",
        **seed_actor
      ).call
    end
    unless PartyRelationship.involving(oceanview).exists?(relationship_kind: "organization_contact", origin_party_id: accounting_contact.id)
      CreatePartyRelationship.new(
        agency: seed_agency,
        origin_party: accounting_contact,
        related_party: oceanview,
        relationship_kind: "organization_contact",
        **seed_actor
      ).call
    end
    unless oceanview.notes.exists?
      CreatePartyNote.new(
        agency: seed_agency,
        party: oceanview,
        body: "Group desk prefers contracted allotments confirmed 90 days out.",
        visibility: "standard",
        pinned: true,
        **seed_actor
      ).call
      CreatePartyNote.new(
        agency: seed_agency,
        party: oceanview,
        body: "Commission schedule last reviewed in spring.",
        visibility: "standard",
        **seed_actor
      ).call
    end

    sparse = seed_agency.parties.find_by(display_name: "Cedar & Salt Expeditions")
    unless sparse
      sparse = CreateParty.new(
        agency: seed_agency,
        party_kind: "organization",
        attributes: { legal_name: "Cedar & Salt Expeditions" },
        actor_identifier: "seed:development",
        privileged: true
      ).call.party
    end

    puts "UX prototype records ready:"
    puts "  OceanView Cruises: #{oceanview.display_name} (#{oceanview.id})"
    puts "  Sparse organization: #{sparse.display_name} (#{sparse.id})"
    puts "  Path: /directory/parties/#{oceanview.id}"
end
