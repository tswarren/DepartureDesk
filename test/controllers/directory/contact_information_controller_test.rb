require "test_helper"

module Directory
  class ContactInformationControllerTest < ActionDispatch::IntegrationTest
    test "administrator can view and create contact information" do
      sign_in_as(users(:one))
      party = parties(:unlinked)

      get directory_party_path(party)
      assert_response :success
      assert_select "nav[aria-label=Party] a[aria-current=page]", text: "Overview"
      assert_select "nav[aria-label=Party] a", text: "Contact information"
      assert_select "nav[aria-label=Party] a", text: "Relationships"
      assert_select "nav[aria-label=Party] a", text: "Notes"

      get directory_party_contact_information_path(party)
      assert_response :success
      assert_select "nav[aria-label=Party] a[aria-current=page]", text: "Contact information"
      assert_select "button[type=submit]", text: "Apply filter"

      assert_difference("PartyContactPoint.count", 1) do
        post directory_party_contact_points_path(party), params: {
          party_contact_point: {
            contact_kind: "email",
            label: "Personal",
            display_address: "alex.directory@example.com",
            email_type: "personal"
          }
        }
      end
      assert_redirected_to directory_party_contact_information_path(party)
      follow_redirect!
      assert_includes response.body, "alex.directory@example.com"
      assert_select "strong.dd-list-title", text: "alex.directory@example.com"
    end

    test "staff can create contact information" do
      sign_in_as(users(:two))

      post directory_party_contact_points_path(parties(:two)), params: {
        party_contact_point: {
          contact_kind: "email",
          display_address: "casey.directory@example.com",
          email_type: "work"
        }
      }
      assert_redirected_to directory_party_contact_information_path(parties(:two))
    end

    test "cross-agency contact pages return not found" do
      sign_in_as(users(:one))

      get directory_party_contact_information_path(parties(:two))
      assert_response :not_found

      post directory_party_contact_points_path(parties(:two)), params: {
        party_contact_point: {
          contact_kind: "email",
          display_address: "stolen@example.com",
          email_type: "personal"
        }
      }
      assert_response :not_found
    end

    test "office selection does not hide contact information" do
      sign_in_as(users(:one))
      extra = CreateOffice.new(
        agency: agencies(:one),
        actor: users(:one),
        name: "Cambridge",
        code: "CAM",
        default_timezone: agencies(:one).default_timezone
      ).call.office
      patch current_office_path, params: { office_id: extra.id }

      create_email_contact!(parties(:unlinked), address: "office-filter@example.com", actor: users(:one))
      get directory_party_contact_information_path(parties(:unlinked))
      assert_response :success
      assert_includes response.body, "office-filter@example.com"
    end

    test "show does not write audit events" do
      sign_in_as(users(:one))
      assert_no_difference("AuditEvent.count") do
        get directory_party_contact_information_path(parties(:unlinked))
        get directory_party_path(parties(:unlinked))
      end
    end
  end
end
