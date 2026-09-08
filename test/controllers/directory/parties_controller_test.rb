require "test_helper"

module Directory
  class PartiesControllerTest < ActionDispatch::IntegrationTest
    test "administrator can list view create and edit parties" do
      sign_in_as(users(:one))

      get directory_parties_path
      assert_response :success
      assert_includes response.body, parties(:one).display_name
      assert_includes response.body, parties(:household_one).display_name
      assert_includes response.body, parties(:organization_one).display_name
      assert_not_includes response.body, parties(:two).display_name
      assert_select "nav[aria-label='Primary navigation'] a[aria-current=page]", text: "Directory"
      assert_select "nav[aria-label=Administration]", count: 0

      get new_directory_party_path
      assert_response :success
      assert_select "a", text: "Person"

      get new_directory_party_path(party_kind: "person")
      assert_response :success
      assert_select "input[name='party[given_name]']"

      assert_difference("Party.count", 1) do
        post directory_parties_path, params: {
          party: {
            party_kind: "person",
            agency_id: agencies(:two).id,
            given_name: "Pat",
            family_name: "Lee"
          }
        }
      end
      party = agencies(:one).parties.find_by!(display_name: "Pat Lee")
      assert_redirected_to directory_party_path(party)
      assert_equal agencies(:one).id, party.agency_id
      assert_equal "person", party.party_kind

      get directory_party_path(party)
      assert_response :success
      assert_includes response.body, "Pat Lee"
      assert_select "nav[aria-label='Primary navigation'] a[aria-current=page]", text: "Directory"
      assert_select "nav[aria-label='Primary navigation'] a[aria-current=page]", text: "Clients", count: 0
      assert_select "nav[aria-label='Primary navigation'] a[aria-current=page]", text: "Suppliers", count: 0

      get edit_directory_party_path(party)
      assert_response :success

      patch directory_party_path(party), params: {
        party: {
          party_kind: "organization",
          preferred_name: "Patricia",
          given_name: "Pat",
          family_name: "Lee",
          lock_version: party.lock_version,
          profile_lock_version: party.person.lock_version
        }
      }
      assert_redirected_to directory_party_path(party)
      assert_equal "person", party.reload.party_kind
      assert_equal "Patricia Lee", party.display_name
    end

    test "staff can list view create and edit parties" do
      sign_in_as(users(:two))

      get directory_parties_path
      assert_response :success
      assert_includes response.body, parties(:two).display_name
      assert_not_includes response.body, parties(:one).display_name

      post directory_parties_path, params: {
        party: { party_kind: "household", name: "Staff Household" }
      }
      household = agencies(:two).parties.find_by!(display_name: "Staff Household")
      assert_redirected_to directory_party_path(household)
      assert_equal "household", household.party_kind

      get directory_party_path(parties(:two))
      assert_response :success

      patch directory_party_path(parties(:two)), params: {
        party: {
          given_name: "Casey",
          family_name: "Nguyen",
          preferred_name: "Cas",
          lock_version: parties(:two).lock_version,
          profile_lock_version: people(:two).lock_version
        }
      }
      assert_redirected_to directory_party_path(parties(:two))
      assert_equal "Cas Nguyen", parties(:two).reload.display_name
    end

    test "unauthenticated requests redirect to sign in" do
      get directory_parties_path
      assert_redirected_to new_session_path
    end

    test "cross-agency show and update return not found" do
      sign_in_as(users(:one))

      get directory_party_path(parties(:two))
      assert_response :not_found

      patch directory_party_path(parties(:two)), params: {
        party: { given_name: "Hacked", family_name: "Name", lock_version: 0, profile_lock_version: 0 }
      }
      assert_response :not_found
    end

    test "kind filter stays inside the current agency" do
      sign_in_as(users(:one))

      get directory_parties_path, params: { party_kind: "person" }

      assert_response :success
      assert_includes response.body, parties(:one).display_name
      assert_not_includes response.body, parties(:household_one).display_name
      assert_not_includes response.body, parties(:two).display_name
      assert_select "button[type=submit]", text: "Apply filter"
      assert_select "[onchange]", count: 0
    end

    test "search finds name email and role filters without leaking other agencies" do
      sign_in_as(users(:one))
      create_email_contact!(parties(:unlinked), address: "alex.search@example.com", actor: users(:one))
      assign_client_role!(parties(:household_one), actor: users(:one))

      get directory_parties_path, params: { q: "Tours" }
      assert_response :success
      assert_includes response.body, "Horizon Tours"
      assert_not_includes response.body, "Alex Morgan"

      get directory_parties_path, params: { q: "alex.search@example.com" }
      assert_response :success
      assert_includes response.body, "Alex Morgan"
      assert_not_includes response.body, parties(:two).display_name

      get directory_parties_path, params: { role: "client" }
      assert_response :success
      assert_includes response.body, "Morgan Household"
      assert_not_includes response.body, "Horizon Tours"
    end

    test "directory index paginates by sort name and id" do
      sign_in_as(users(:one))
      CreateParty.new(
        agency: agencies(:one),
        actor: users(:one),
        party_kind: "person",
        attributes: { given_name: "Pat", family_name: "Lee" }
      ).call

      previous_page_size = Directory::PartiesController.page_size
      Directory::PartiesController.page_size = 2
      begin
        get directory_parties_path, params: { party_kind: "person" }
        assert_response :success
        assert_includes response.body, parties(:one).display_name
        assert_select "a", text: "Next"
        assert_select "a", text: "Previous", count: 0

        get directory_parties_path, params: { party_kind: "person", page: 2 }
        assert_response :success
        assert_includes response.body, parties(:unlinked).display_name
        assert_select "table.dd-table a", text: parties(:one).display_name, count: 0
        assert_select "a", text: "Previous"
      ensure
        Directory::PartiesController.page_size = previous_page_size
      end
    end

    test "directory index and show do not filter by current office" do
      sign_in_as(users(:one))
      extra = CreateOffice.new(
        agency: agencies(:one),
        actor: users(:one),
        name: "Boston",
        code: "BOS",
        default_timezone: agencies(:one).default_timezone
      ).call.office
      patch current_office_path, params: { office_id: extra.id }
      assert_redirected_to root_url

      get directory_parties_path
      assert_response :success
      assert_includes response.body, parties(:one).display_name
      assert_includes response.body, parties(:organization_one).display_name

      get directory_party_path(parties(:household_one))
      assert_response :success
      assert_includes response.body, "Morgan Household"
    end

    test "validation errors render accessibly" do
      sign_in_as(users(:one))

      post directory_parties_path, params: {
        party: { party_kind: "person", given_name: "", family_name: "" }
      }

      assert_response :unprocessable_entity
      assert_select "[aria-invalid=true]"
    end

    test "overview omits suppressed and deactivated primary destinations" do
      sign_in_as(users(:one))
      party = parties(:unlinked)
      contact_point = create_email_contact!(party, address: "primary.inbox@example.com", actor: users(:one))
      SetContactPointPrimary.new(
        agency: agencies(:one),
        actor: users(:one),
        party:,
        contact_point:,
        purpose: "general"
      ).call

      get directory_party_path(party)
      assert_response :success
      assert_includes response.body, "primary.inbox@example.com"
      assert_select "a", text: "Manage"
      assert_select "a", text: /View all \d+/, count: 0

      SuppressPartyContactPoint.new(
        agency: agencies(:one),
        actor: users(:one),
        party:,
        contact_point:,
        reason: "Mailbox abandoned"
      ).call

      get directory_party_path(party)
      assert_response :success
      assert_not_includes response.body, "primary.inbox@example.com"
      assert_includes response.body, "need attention"
      assert_includes response.body, "marked do not use or deactivated"
      assert_select ".dd-attention-callout"
      assert_select ".dd-info-callout", count: 0

      UnsuppressPartyContactPoint.new(
        agency: agencies(:one),
        actor: users(:one),
        party:,
        contact_point:
      ).call
      DeactivatePartyContactPoint.new(
        agency: agencies(:one),
        actor: users(:one),
        party:,
        contact_point:,
        reason: "Replaced"
      ).call

      get directory_party_path(party)
      assert_response :success
      assert_not_includes response.body, "primary.inbox@example.com"
      assert_includes response.body, "need attention"
    end

    test "overview caps distinct contacts and labels view all when more than four exist" do
      sign_in_as(users(:one))
      person = create_person!(agencies(:one), given_name: "Overview", family_name: "Contacts")
      party = person.party
      shared = create_email_contact!(party, address: "shared.primary@example.com", actor: users(:one))
      SetContactPointPrimary.new(
        agency: agencies(:one),
        actor: users(:one),
        party:,
        contact_point: shared,
        purpose: "general"
      ).call
      SetContactPointPrimary.new(
        agency: agencies(:one),
        actor: users(:one),
        party:,
        contact_point: shared,
        purpose: "billing"
      ).call
      5.times do |index|
        create_email_contact!(party, address: "extra#{index}@example.com", actor: users(:one))
      end

      get directory_party_path(party)
      assert_response :success
      assert_select "a", text: "View all 6"
      assert_select ".dd-content-grid--main-aside > .dd-stack > article:first-child .dd-contact-value", count: 4
      assert_includes response.body, "shared.primary@example.com"
      assert_not_includes response.body, "extra3@example.com"
      assert_not_includes response.body, "extra4@example.com"
    end

    test "staff can deactivate an unblocked party and include it when requested" do
      sign_in_as(users(:staff_one))
      party = parties(:unlinked)

      get confirm_deactivate_directory_party_path(party)
      assert_response :success
      assert_select "input#party_deactivation_reason"
      assert_select "input[type=submit][value='Deactivate party']"

      post deactivate_directory_party_path(party), params: { reason: "Unused duplicate" }
      assert_redirected_to directory_party_record_path(party)
      follow_redirect!
      assert_includes response.body, "Party deactivated."
      assert party.reload.deactivated?

      get directory_parties_path
      assert_response :success
      assert_not_includes response.body, party.display_name

      get directory_parties_path(include_inactive: "1")
      assert_response :success
      assert_includes response.body, party.display_name

      post reactivate_directory_party_path(party), params: { reason: "Needed" }
      assert_redirected_to directory_party_record_path(party)
      assert party.reload.active?
    end

    test "cross-agency party lifecycle routes return not found" do
      sign_in_as(users(:one))

      get confirm_deactivate_directory_party_path(parties(:two))
      assert_response :not_found

      post deactivate_directory_party_path(parties(:two)), params: { reason: "Leave" }
      assert_response :not_found
      assert parties(:two).reload.active?
    end

    test "create warns on a likely duplicate and can use the existing party" do
      sign_in_as(users(:one))
      contact = create_email_contact!(parties(:unlinked), address: "alex.inbox@example.com", actor: users(:one))
      AssignContactPointPurpose.new(
        agency: agencies(:one),
        actor: users(:one),
        party: parties(:unlinked),
        contact_point: contact,
        purpose: "general",
        priority: 1
      ).call

      assert_no_difference("Party.count") do
        post directory_parties_path, params: {
          party: { party_kind: "person", given_name: "Alex", family_name: "Morgan" }
        }
      end
      assert_response :unprocessable_entity
      assert_includes response.body, "Possible existing records"
      assert_includes response.body, "Alex Morgan"
      assert_includes response.body, "alex.inbox@example.com"
      assert_not_includes response.body, "Restricted credit discussion for administrators only."
      assert_select "a", text: "Use this record"
    end

    test "staff can create a justified separate identity after a strong warning" do
      sign_in_as(users(:staff_one))
      people(:unlinked).update!(date_of_birth: Date.new(1990, 5, 1))

      post directory_parties_path, params: {
        party: {
          party_kind: "person",
          given_name: "Alex",
          family_name: "Morgan",
          date_of_birth: "1990-05-01"
        }
      }
      assert_response :unprocessable_entity
      assert_includes response.body, "Reason for creating a separate identity"

      assert_difference("Party.count", 1) do
        post directory_parties_path, params: {
          party: {
            party_kind: "person",
            given_name: "Alex",
            family_name: "Morgan",
            date_of_birth: "1990-05-01",
            create_anyway: "1",
            acknowledged_strength: "strong",
            acknowledged_candidate_ids: [ parties(:unlinked).id ],
            duplicate_override_reason: "Twins with the same name"
          }
        }
      end
      party = agencies(:one).parties.order(:created_at).last
      assert_redirected_to directory_party_path(party)
      event = agencies(:one).audit_events.where(action: "directory.party_created").order(:created_at).last
      assert_equal "strong", event.details["duplicate_override_strength"]
      assert_equal "Twins with the same name", event.details["duplicate_override_reason"]
    end
  end
end
