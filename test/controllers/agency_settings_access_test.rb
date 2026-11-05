require "test_helper"

# S-02 and S-03 routes: Agency Admin only, and another agency's records are
# not found (AGENTS.md invariant 12).
class AgencySettingsAccessTest < ActionDispatch::IntegrationTest
  test "staff are refused every S-02 and S-03 write" do
    sign_in_as agency_users(:harbor_staff)
    target = agency_users(:harbor_baseline_staff)

    get edit_administration_agency_user_permissions_path(target)
    assert_redirected_to root_path
    patch administration_agency_user_permissions_path(target), params: { agency_user: { permissions: [ "financial_records" ], lock_version: target.lock_version } }
    assert_redirected_to root_path
    post administration_traveler_types_path, params: { traveler_type: { name: "Senior" } }
    assert_redirected_to root_path
    post administration_footer_preview_path, params: { source: "**x**" }
    assert_redirected_to root_path
    patch administration_agency_path, params: { agency: { contact_email: "x@example.com" } }
    assert_redirected_to root_path

    assert_empty target.reload.granted_permissions
    assert_not agencies(:harbor).traveler_types.exists?(name: "Senior")
    assert_nil agencies(:harbor).reload.contact_email
  end

  test "another agency's user and traveler type are not found" do
    sign_in_as agency_users(:harbor_admin)

    get edit_administration_agency_user_permissions_path(agency_users(:cove_admin))
    assert_response :not_found
    get edit_administration_traveler_type_path(traveler_types(:cove_adult))
    assert_response :not_found
    patch administration_traveler_type_position_path(traveler_types(:cove_adult)), params: { direction: "up" }
    assert_response :not_found
  end

  test "an agency admin's permissions page redirects, since admins hold every permission" do
    sign_in_as agency_users(:harbor_admin)
    get edit_administration_agency_user_permissions_path(agency_users(:harbor_admin))
    assert_redirected_to administration_agency_user_path(agency_users(:harbor_admin))
  end

  test "a stale permissions form re-renders with the error and the submitted choices" do
    sign_in_as agency_users(:harbor_admin)
    target = agency_users(:harbor_baseline_staff)

    patch administration_agency_user_permissions_path(target), params: { agency_user: { permissions: [ "passport_access" ], lock_version: target.lock_version + 1 } }
    assert_response :unprocessable_entity
    assert_select "#form-error-summary a[href='#agency_user_permissions']"
    assert_select "input[type=checkbox][value=passport_access][checked]"
    assert_empty target.reload.granted_permissions
  end

  test "the footer preview renders only allowed Markdown" do
    sign_in_as agency_users(:harbor_admin)
    post administration_footer_preview_path, params: { source: "**Bold** <script>alert(1)</script> [x](javascript:alert(1))" }
    assert_response :success
    assert_includes response.body, "<strong>Bold</strong>"
    assert_no_match(/<script|javascript:/, response.body)
  end

  test "the profile form re-renders invalid values with field errors" do
    sign_in_as agency_users(:harbor_admin)
    patch administration_agency_path, params: { agency: { contact_email: "nope", hold_duration_days: "0", lock_version: agencies(:harbor).lock_version } }

    assert_response :unprocessable_entity
    assert_select "#form-error-summary a[href='#agency_contact_email']"
    assert_select "#agency_contact_email[aria-invalid=true][value=nope]"
    assert_select "#form-error-summary", text: /Client hold duration/
    assert_nil agencies(:harbor).reload.contact_email
  end
end
