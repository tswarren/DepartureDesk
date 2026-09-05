require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "resolves exactly one usable membership" do
    user = users(:one)

    assert_equal agency_memberships(:one), user.usable_agency_membership
    assert_equal agencies(:one), user.agency
  end

  test "usable_agency_membership is nil without an active membership" do
    user = User.create!(
      email_address: "no-membership@example.com",
      password: "password",
      password_confirmation: "password"
    )

    assert_nil user.usable_agency_membership
    assert_nil user.agency
  end

  test "usable_agency_membership is nil when the membership is suspended" do
    agency_memberships(:one).update!(status: :suspended)

    assert_nil users(:one).usable_agency_membership
    assert_nil users(:one).agency
  end

  test "usable_agency_membership is nil when the agency is suspended" do
    agencies(:one).update!(status: :suspended)

    assert_nil users(:one).usable_agency_membership
    assert_nil users(:one).agency
  end

  test "usable_agency_membership is nil when the agency is closed" do
    agencies(:one).update!(status: :closed)

    assert_nil users(:one).usable_agency_membership
    assert_nil users(:one).agency
  end

  test "usable_agency_membership fails closed when two active memberships load" do
    user = users(:one)
    first = agency_memberships(:one)
    second = AgencyMembership.new(
      user: user,
      agency: agencies(:two),
      role: "staff",
      status: "active"
    )
    relation = AmbiguousMembershipRelation.new([ first, second ])

    user.define_singleton_method(:active_agency_memberships) { relation }

    assert_nil user.usable_agency_membership
    assert_nil user.agency
  end
end
