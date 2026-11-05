require "test_helper"

# S-09 Departure team routes (ACC-09, OPS-12).
class DepartureTeamMembersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @departure = CreateDeparture.new(agency: @agency, actor: @admin, attributes: { name: "Team Routes" }).call.record
  end

  test "a user with departure management adds a member, makes them default owner and removes them" do
    sign_in_as agency_users(:harbor_staff)
    member = agency_users(:harbor_baseline_staff)

    post departure_team_members_path(@departure), params: { team_member: { agency_user_id: member.id } }
    assert_redirected_to departure_path(@departure, anchor: "team")
    follow_redirect!
    assert_select "#team th", text: member.display_name

    patch default_owner_departure_team_members_path(@departure), params: { agency_user_id: member.id }
    assert_equal member, @departure.reload.default_task_owner

    delete departure_team_member_path(@departure, member.id)
    assert_not @departure.reload.team_members.exists?(agency_user_id: member.id)
  end

  test "staff without departure management see the team but cannot change it" do
    sign_in_as agency_users(:harbor_baseline_staff)
    get departure_path(@departure)
    assert_response :success
    assert_select "#team th", text: @admin.display_name
    assert_select "#team button", count: 0
    assert_select "#team form", count: 0

    post departure_team_members_path(@departure), params: { team_member: { agency_user_id: agency_users(:harbor_staff).id } }
    assert_redirected_to root_path
    assert_equal [ @admin ], @departure.reload.team_members.map(&:agency_user)
  end

  test "an invalid choice is reported, not saved" do
    sign_in_as @admin
    post departure_team_members_path(@departure), params: { team_member: { agency_user_id: agency_users(:harbor_suspended).id } }
    assert_redirected_to departure_path(@departure, anchor: "team")
    assert_equal "That agency user is not active.", flash[:alert]
  end
end
