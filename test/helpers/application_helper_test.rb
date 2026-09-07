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
    assert_includes party_kind_badge(parties(:one)), "Person"
    assert_includes party_status_badge(parties(:one)), "Active"
    assert_equal "active", agencies(:one).status
    assert_equal "active", offices(:one).status
  end

  test "satisfied communication preference lists only that kind" do
    party = preference_party(
      email: "alex@example.com",
      phone: "415-555-0199"
    )
    profile = ClientProfile.new(communication_preference: "email")

    assert_equal [ "alex@example.com" ], client_preference_contact_lines(party, profile, Date.current)
  end

  test "missing preferred kind lists labeled alternatives" do
    party = preference_party(phone: "415-555-0199")
    profile = ClientProfile.new(communication_preference: "email")
    lines = client_preference_contact_lines(party, profile, Date.current)

    assert_equal [ "Preferred contact unavailable.", "Phone: 415-555-0199" ], lines
  end

  test "no preference lists every general primary by kind" do
    party = preference_party(
      email: "alex@example.com",
      phone: "415-555-0199"
    )
    profile = ClientProfile.new(communication_preference: "no_preference")
    lines = client_preference_contact_lines(party, profile, Date.current)

    assert_equal [ "Email: alex@example.com", "Phone: 415-555-0199" ], lines
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

  private

  PreferencePoint = Struct.new(:display_value) do
    def eligible_destination? = true
  end

  PreferenceAssignment = Struct.new(:contact_kind, :contact_point) do
    def general? = true
    def primary? = true
    def current_on?(*) = true
  end

  PreferenceParty = Struct.new(:contact_point_purpose_assignments)

  def preference_party(email: nil, phone: nil)
    assignments = []
    assignments << PreferenceAssignment.new("email", PreferencePoint.new(email)) if email
    assignments << PreferenceAssignment.new("phone", PreferencePoint.new(phone)) if phone
    PreferenceParty.new(assignments)
  end
end
