require "test_helper"

class CurrentTest < ActiveSupport::TestCase
  setup { Current.reset }
  teardown { Current.reset }

  test "derives user membership and agency from the session" do
    session = users(:one).sessions.create!

    Current.session = session

    assert_equal users(:one), Current.user
    assert_equal agency_memberships(:one), Current.agency_membership
    assert_equal agencies(:one), Current.agency
  end

  test "has no tenant context without a session" do
    assert_nil Current.session
    assert_nil Current.user
    assert_nil Current.agency_membership
    assert_nil Current.agency
  end

  test "has no tenant context when the membership is suspended" do
    agency_memberships(:one).update!(status: :suspended)
    Current.session = users(:one).sessions.create!

    assert_equal users(:one), Current.user
    assert_nil Current.agency_membership
    assert_nil Current.agency
  end

  test "has no tenant context when the agency is suspended" do
    agencies(:one).update!(status: :suspended)
    Current.session = users(:one).sessions.create!

    assert_nil Current.agency_membership
    assert_nil Current.agency
  end

  test "has no tenant context when the agency is closed" do
    agencies(:one).update!(status: :closed)
    Current.session = users(:one).sessions.create!

    assert_nil Current.agency_membership
    assert_nil Current.agency
  end

  test "has no tenant context when active memberships are ambiguous" do
    user = users(:one)
    relation = AmbiguousMembershipRelation.new(
      [
        agency_memberships(:one),
        AgencyMembership.new(
          user: user,
          agency: agencies(:two),
          role: "staff",
          status: "active"
        )
      ]
    )
    user.define_singleton_method(:active_agency_memberships) { relation }
    Current.session = user.sessions.create!

    assert_nil Current.agency_membership
    assert_nil Current.agency
  end

  test "resets request-local context" do
    Current.session = users(:one).sessions.create!

    assert Current.agency.present?

    Current.reset

    assert_nil Current.session
    assert_nil Current.user
    assert_nil Current.agency_membership
    assert_nil Current.agency
  end
end
