require "test_helper"

class CurrentOfficeTest < ActiveSupport::TestCase
  setup { Current.reset }
  teardown { Current.reset }

  test "uses a stored session office when it is active and accessible" do
    session = users(:one).sessions.create!(office: offices(:one))
    Current.session = session

    assert_equal offices(:one), Current.office
    assert_equal offices(:one).id, session.reload.office_id
  end

  test "auto-selects a sole accessible office in memory without persisting" do
    session = users(:one).sessions.create!
    Current.session = session

    assert_equal offices(:one), Current.office
    assert_nil session.reload.office_id
  end

  test "uses the default office in memory when more than one office is accessible" do
    create_second_office
    session = users(:one).sessions.create!
    Current.session = session

    assert_equal offices(:one), Current.office
    assert_nil session.reload.office_id
  end

  test "does not invent a current office when several offices are accessible and none is default" do
    extra = create_second_office
    office_assignments(:one).update!(is_default: false)
    GrantOfficeAccess.new(
      agency: agencies(:one),
      actor: users(:one),
      membership: agency_memberships(:one),
      office: extra
    ).call
    session = users(:one).sessions.create!
    Current.session = session

    assert_nil Current.office
    assert_nil session.reload.office_id
  end

  test "ignores a stored office from another agency" do
    session = users(:one).sessions.create!(office: offices(:two))
    Current.session = session

    assert_equal offices(:one), Current.office
    assert_equal offices(:two).id, session.reload.office_id
  end

  private

  def create_second_office
    CreateOffice.new(
      agency: agencies(:one),
      actor: users(:one),
      name: "Boston",
      code: "BOS",
      default_timezone: agencies(:one).default_timezone
    ).call.office
  end
end
