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

  test "new departure form leaves required dates blank" do
    sign_in_as(users(:one))

    get new_departure_path

    assert_response :success
    assert_select "input[name='departure[start_date]']" do |inputs|
      assert_equal "", inputs.first["value"].to_s
    end
    assert_select "input[name='departure[end_date]']" do |inputs|
      assert_equal "", inputs.first["value"].to_s
    end
    assert_not_includes response.body, "2027-07-12"
    assert_not_includes response.body, "2027-07-19"
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

  test "party role selector searches agency parties and restricts group leaders to people" do
    departure = create_departure!(agencies(:one), actor: users(:one))
    distinctive = create_person!(agencies(:one), given_name: "Quorum", family_name: "Zebrafilter").party
    sign_in_as(users(:one))

    get departure_path(departure), params: { q: "Zebrafilter", role: "organizer" }

    assert_response :success
    assert_select "option[value=?]", distinctive.id
    assert_select "option", text: /Horizon Tours/, count: 0
    assert_select "option", text: /Casey Nguyen/, count: 0

    get departure_path(departure), params: { role: "group_leader" }

    assert_response :success
    assert_select "option[value=?]", parties(:unlinked).id
    assert_select "option[value=?]", parties(:organization_one).id, count: 0
    assert_select "option", text: /Horizon Tours/, count: 0
  end

  test "reassigning the same party role returns a conflict instead of a server error" do
    departure = create_departure!(agencies(:one), actor: users(:one))
    AssignDeparturePartyRole.new(
      agency: agencies(:one),
      actor: users(:one),
      departure:,
      party: parties(:unlinked),
      role: "organizer"
    ).call
    sign_in_as(users(:one))

    post assign_party_role_departure_path(departure), params: {
      party_id: parties(:unlinked).id,
      role: "organizer",
      lock_version: departure.lock_version
    }

    assert_redirected_to departure_path(departure)
    assert_match(/overlapping period/, flash[:alert])
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
    create_departure!(
      agencies(:one),
      actor: users(:one),
      office: extra,
      travel_program: program,
      name: "Hidden Boston",
      start_date: Date.new(2027, 8, 1),
      end_date: Date.new(2027, 8, 8)
    )

    sign_in_as(users(:staff_one))
    get travel_programs_path

    assert_response :success
    assert_includes response.body, "Atlantic Series"
    assert_select "td", text: "0"
    assert_select "td", text: "—"
    assert_not_includes response.body, "Hidden Boston"
    assert_not_includes response.body, "August 1, 2027"
  end
end
