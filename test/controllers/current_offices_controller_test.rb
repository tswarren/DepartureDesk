require "test_helper"

class CurrentOfficesControllerTest < ActionDispatch::IntegrationTest
  test "auto-select does not persist on GET" do
    sign_in_as(users(:one))

    get root_path

    assert_response :success
    assert_nil users(:one).sessions.last.reload.office_id
  end

  test "login persists the default office" do
    post session_path, params: {
      email_address: users(:one).email_address,
      password: "password"
    }

    session = users(:one).sessions.last
    assert_equal offices(:one).id, session.office_id
  end

  test "login persists the default office when several offices are accessible" do
    CreateOffice.new(
      agency: agencies(:one),
      actor: users(:one),
      name: "Boston",
      code: "BOS",
      default_timezone: agencies(:one).default_timezone
    ).call

    post session_path, params: {
      email_address: users(:one).email_address,
      password: "password"
    }

    assert_equal offices(:one).id, users(:one).sessions.last.office_id
  end

  test "an invalid stored office is ignored without destroying the agency session or writing during GET" do
    sign_in_as(users(:one))
    session = users(:one).sessions.last
    session.update!(office: offices(:two))

    assert_no_difference("Session.count") do
      get root_path
    end

    assert_response :success
    assert_includes response.body, agencies(:one).name
    assert_equal offices(:two).id, session.reload.office_id
  end

  test "selecting an office persists only through PATCH" do
    extra = CreateOffice.new(
      agency: agencies(:one),
      actor: users(:one),
      name: "Boston",
      code: "BOS",
      default_timezone: agencies(:one).default_timezone
    ).call.office
    sign_in_as(users(:one))

    get edit_current_office_path
    assert_response :success
    assert_select "label", text: "#{offices(:one).name} (#{offices(:one).code})"
    assert_select "input[type=radio][name=office_id][value=?]", extra.id
    assert_select "input[type=radio][name=office_id][value=?]", offices(:one).id
    assert_nil users(:one).sessions.last.reload.office_id

    patch current_office_path, params: { office_id: extra.id }

    assert_redirected_to root_url
    assert_equal extra.id, users(:one).sessions.last.reload.office_id
  end

  test "a forged foreign office UUID is not found" do
    sign_in_as(users(:one))

    patch current_office_path, params: { office_id: offices(:two).id }

    assert_response :not_found
    assert_nil users(:one).sessions.last.reload.office_id
  end
end
