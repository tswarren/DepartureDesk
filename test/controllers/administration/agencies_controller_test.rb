require "test_helper"

module Administration
  class AgenciesControllerTest < ActionDispatch::IntegrationTest
    test "administrator can view the current agency" do
      sign_in_as(users(:one))

      get administration_agency_path

      assert_response :success
      assert_includes response.body, agencies(:one).name
      assert_includes response.body, "Administration"
    end

    test "administrator can edit and update the current agency" do
      sign_in_as(users(:one))

      get edit_administration_agency_path
      assert_response :success
      assert_select "select#agency_country_code option[value=?]", "CA"
      assert_select "select#agency_default_timezone option[value=?]", "America/Toronto"

      assert_difference("AuditEvent.count", 1) do
        patch administration_agency_path, params: {
          agency: {
            name: "Sunrise Travel Group",
            legal_name: "Sunrise Travel LLC",
            country_code: "CA",
            default_timezone: "America/Toronto",
            default_currency: "CAD",
            lock_version: agencies(:one).lock_version
          }
        }
      end

      assert_redirected_to administration_agency_path
      agency = agencies(:one).reload
      assert_equal "Sunrise Travel Group", agency.name
      assert_equal "Sunrise Travel LLC", agency.legal_name
      assert_equal "CA", agency.country_code
      event = AuditEvent.last
      assert_equal "agency.profile_updated", event.action
      assert_equal agency.id, event.agency_id
      assert_equal users(:one).id, event.actor_user_id
    end

    test "staff cannot enter the administration surface" do
      sign_in_as(users(:two))

      get administration_agency_path
      assert_redirected_to root_url
      assert_equal "You are not authorized to do that.", flash[:alert]
      assert_equal 0, AuditEvent.count
    end

    test "staff cannot mutate the administration surface" do
      sign_in_as(users(:two))

      assert_no_difference("AuditEvent.count") do
        patch administration_agency_path, params: {
          agency: { name: "Hijacked", lock_version: agencies(:two).lock_version }
        }
      end

      assert_redirected_to root_url
      assert_equal "Pacific Travel", agencies(:two).reload.name
    end

    test "forged agency_id and status values are ignored" do
      sign_in_as(users(:one))

      patch administration_agency_path, params: {
        agency: {
          name: "Sunrise Travel Group",
          agency_id: agencies(:two).id,
          id: agencies(:two).id,
          status: "closed",
          lock_version: agencies(:one).lock_version
        }
      }

      assert_redirected_to administration_agency_path
      assert_equal "Sunrise Travel Group", agencies(:one).reload.name
      assert_equal "active", agencies(:one).status
      assert_equal "Pacific Travel", agencies(:two).reload.name
      assert_equal "active", agencies(:two).status
    end

    test "there is no tenant-facing agency create or destroy route" do
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("/administration/agency", method: :post)
      end
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("/administration/agency", method: :delete)
      end
    end

    test "failed validation creates no audit event" do
      sign_in_as(users(:one))

      assert_no_difference("AuditEvent.count") do
        patch administration_agency_path, params: {
          agency: {
            name: "",
            lock_version: agencies(:one).lock_version
          }
        }
      end

      assert_response :unprocessable_entity
    end

    test "stale update keeps submitted values and writes no audit" do
      sign_in_as(users(:one))
      agencies(:one).update!(name: "Sunrise Travel Group")

      assert_no_difference("AuditEvent.count") do
        patch administration_agency_path, params: {
          agency: {
            name: "Harbor View Travel",
            legal_name: "Harbor View LLC",
            country_code: "US",
            default_timezone: "America/New_York",
            default_currency: "USD",
            lock_version: 0
          }
        }
      end

      assert_response :conflict
      assert_includes response.body, "Harbor View Travel"
      assert_includes response.body, "Harbor View LLC"
      assert_equal "Sunrise Travel Group", agencies(:one).reload.name
    end
  end
end
