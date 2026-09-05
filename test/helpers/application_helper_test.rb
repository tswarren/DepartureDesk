require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "membership badges use title-case labels without changing stored enums" do
    membership = agency_memberships(:one)

    assert_equal "administrator", membership.role
    assert_equal "active", membership.status
    assert_includes membership_role_badge(membership), "Administrator"
    assert_includes membership_status_badge(membership), "Active"
  end

  test "agency and office badges use title-case labels" do
    assert_includes agency_status_badge(agencies(:one)), "Active"
    assert_includes office_status_badge(offices(:one)), "Active"
    assert_equal "active", agencies(:one).status
    assert_equal "active", offices(:one).status
  end

  test "field helpers expose invalid state and an error id" do
    agency = agencies(:one)
    agency.errors.add(:name, "can't be blank")

    aria = field_aria(agency, :name)

    assert_equal true, aria[:invalid]
    assert_equal "agency_name_error", aria[:describedby]
    assert_match(/blank/, field_error(agency, :name))
    assert_includes field_error(agency, :name), 'id="agency_name_error"'
    assert_nil field_error(agency, :legal_name)
  end
end
