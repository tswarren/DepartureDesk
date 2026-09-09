require "test_helper"

class DeparturesControllerTest < ActionDispatch::IntegrationTest
  test "staff can open the departure index" do
    sign_in_as(users(:staff_one))

    get departures_path

    assert_response :success
    assert_select "h1.dd-page-title", text: "Departures"
    assert_select "nav[aria-label='Primary navigation'] a[href=?]", departures_path, text: "Departures"
  end

  test "staff do not see departures in inaccessible offices" do
    extra = CreateOffice.new(
      agency: agencies(:one),
      actor: users(:one),
      name: "Boston",
      code: "BOS",
      default_timezone: agencies(:one).default_timezone
    ).call.office
    hidden = create_departure!(agencies(:one), actor: users(:one), office: extra, name: "Hidden Boston")
    visible = create_departure!(agencies(:one), actor: users(:staff_one), name: "Visible MAIN")

    sign_in_as(users(:staff_one))
    get departures_path

    assert_response :success
    assert_includes response.body, visible.name
    assert_not_includes response.body, hidden.name
  end

  test "staff cannot open an inaccessible departure" do
    extra = CreateOffice.new(
      agency: agencies(:one),
      actor: users(:one),
      name: "Boston",
      code: "BOS",
      default_timezone: agencies(:one).default_timezone
    ).call.office
    hidden = create_departure!(agencies(:one), actor: users(:one), office: extra, name: "Hidden Boston")

    sign_in_as(users(:staff_one))
    get departure_path(hidden)

    assert_response :not_found
  end

  test "cross-agency departure UUIDs do not disclose existence" do
    foreign = create_departure!(agencies(:two), actor: users(:two))
    sign_in_as(users(:one))

    get departure_path(foreign)

    assert_response :not_found
  end

  test "creates a departure from the form and retains the idempotency key on error" do
    sign_in_as(users(:one))
    key = SecureRandom.uuid

    post departures_path, params: {
      departure: {
        name: "",
        office_id: offices(:one).id,
        start_date: "2027-07-12",
        end_date: "2027-07-19",
        default_currency: "USD",
        group_manager_membership_id: agency_memberships(:one).id,
        creation_idempotency_key: key
      }
    }

    assert_response :unprocessable_entity
    assert_select "input[name='departure[creation_idempotency_key]'][value=?]", key
  end

  test "successful create issues a reference" do
    sign_in_as(users(:one))

    assert_difference -> { agencies(:one).departures.count }, 1 do
      post departures_path, params: {
        departure: {
          name: "Smith Family Reunion Cruise",
          office_id: offices(:one).id,
          start_date: "2027-07-12",
          end_date: "2027-07-19",
          default_currency: "USD",
          group_manager_membership_id: agency_memberships(:one).id,
          creation_idempotency_key: SecureRandom.uuid
        }
      }
    end

    departure = agencies(:one).departures.order(:created_at).last
    assert_redirected_to departure_path(departure)
    assert_match(/\AD-\d{6,}\z/, departure.departure_reference)
  end

  test "staff program index does not disclose inaccessible linked departures" do
    extra = CreateOffice.new(
      agency: agencies(:one),
      actor: users(:one),
      name: "Boston",
      code: "BOS",
      default_timezone: agencies(:one).default_timezone
    ).call.office
    program = create_travel_program!(agencies(:one), actor: users(:one), name: "Atlantic Series")
    create_departure!(agencies(:one), actor: users(:one), office: extra, travel_program: program, name: "Hidden Boston")

    sign_in_as(users(:staff_one))
    get travel_programs_path

    assert_response :success
    assert_includes response.body, "Atlantic Series"
    assert_select "td", text: "0"
    assert_not_includes response.body, "Hidden Boston"
  end
end
