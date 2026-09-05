require "test_helper"

module Administration
  class OfficesControllerTest < ActionDispatch::IntegrationTest
    FOREIGN_OFFICE_MUTATIONS = [
      [ :get, :administration_office_path, {} ],
      [ :get, :edit_administration_office_path, {} ],
      [ :patch, :administration_office_path, { office: { name: "Forged", default_timezone: "UTC" } } ],
      [ :post, :deactivate_administration_office_path, { reason: "Forged" } ],
      [ :post, :reactivate_administration_office_path, { reason: "Forged" } ]
    ].freeze

    test "index lists the current agency offices" do
      sign_in_as(users(:one))

      get administration_offices_path

      assert_response :success
      assert_includes response.body, offices(:one).name
      assert_includes response.body, offices(:one).code
      assert_not_includes response.body, offices(:two).name
      assert_select "nav[aria-label=Administration]" do
        assert_select "a[href=?]", administration_agency_path
        assert_select "a[href=?]", administration_team_members_path
        assert_select "a[href=?][aria-current=page]", administration_offices_path
      end
    end

    test "show keeps the deactivate confirm and destructive label" do
      sign_in_as(users(:one))

      get administration_office_path(offices(:one))

      assert_response :success
      assert_select "h2", "Office lifecycle"
      assert_select "input[type=submit][value='Deactivate office']"
      assert_select "[data-turbo-confirm=?]", "Deactivate #{offices(:one).name}?"
    end

    test "invalid create exposes field errors and aria-invalid" do
      sign_in_as(users(:one))

      post administration_offices_path, params: {
        office: {
          name: "",
          code: "!",
          default_timezone: "America/New_York"
        }
      }

      assert_response :unprocessable_entity
      assert_select "input[name='office[name]'][aria-invalid=true]"
      assert_select "input[name='office[code]'][aria-invalid=true]"
      assert_select "#office_name_error"
      assert_select "#office_code_error"
    end

    test "creates an office" do
      sign_in_as(users(:one))

      assert_difference("Office.count", 1) do
        post administration_offices_path, params: {
          office: {
            name: "Boston",
            code: "BOS",
            default_timezone: "America/New_York"
          }
        }
      end

      office = agencies(:one).offices.find_by!(code: "BOS")
      assert_redirected_to administration_office_path(office)
    end

    test "staff cannot view offices" do
      sign_in_as(users(:two))

      get administration_offices_path
      assert_redirected_to root_url
    end

    FOREIGN_OFFICE_MUTATIONS.each do |http_method, path_helper, params|
      test "foreign office UUID #{http_method} #{path_helper} returns 404 with no side effects" do
        sign_in_as(users(:one))
        office = offices(:two)
        snapshot = office.attributes.slice("name", "status", "code", "lock_version")
        audits = AuditEvent.count

        send(http_method, public_send(path_helper, office), params:)

        assert_response :not_found
        assert_equal snapshot, office.reload.attributes.slice("name", "status", "code", "lock_version")
        assert_equal audits, AuditEvent.count
      end
    end

    test "foreign office UUID cannot be granted on a local membership" do
      sign_in_as(users(:one))
      audits = AuditEvent.count

      post grant_office_administration_team_member_path(agency_memberships(:one)),
        params: { office_id: offices(:two).id }

      assert_response :not_found
      assert_equal audits, AuditEvent.count
      assert_not OfficeAssignment.exists?(agency_membership: agency_memberships(:one), office: offices(:two))
    end
  end
end
