require "test_helper"

class PartyContactPointCommandsTest < ActiveSupport::TestCase
  test "create update suppress deactivate and re-add follow the contact lifecycle" do
    party = parties(:unlinked)
    created = CreatePartyContactPoint.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      contact_kind: "email",
      label: "Personal",
      attributes: { display_address: "alex.personal@example.com", email_type: "personal" }
    ).call.contact_point

    assert created.active?
    assert_equal "alex.personal@example.com", created.email_address.display_address
    assert_equal "alex.personal@example.com", created.normalized_value
    assert_not created.email_address.display_address.match?(/[A-Z]/)

    UpdatePartyContactPoint.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      contact_point: created,
      label: "Personal inbox",
      attributes: { display_address: "Alex.Personal@example.com", email_type: "personal" }
    ).call
    created.reload
    assert_equal "Alex.Personal@example.com", created.email_address.display_address
    assert_equal "alex.personal@example.com", created.normalized_value

    SuppressPartyContactPoint.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      contact_point: created,
      reason: "Mailbox abandoned"
    ).call
    assert created.reload.suppressed?
    assert_not created.eligible_destination?

    error = assert_raises(MembershipCommand::Error) do
      CreatePartyContactPoint.new(
        agency: agencies(:one),
        actor: users(:one),
        party:,
        contact_kind: "email",
        attributes: { display_address: "alex.personal@example.com", email_type: "personal" }
      ).call
    end
    assert_equal :conflict, error.code

    UnsuppressPartyContactPoint.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      contact_point: created
    ).call
    DeactivatePartyContactPoint.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      contact_point: created,
      reason: "Moved to a new address"
    ).call
    assert created.reload.deactivated?

    restored = CreatePartyContactPoint.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      contact_kind: "email",
      label: "Personal",
      attributes: { display_address: "alex.personal@example.com", email_type: "personal" }
    ).call.contact_point

    assert_equal created.id, restored.id
    assert restored.active?
    assert_not restored.suppressed?
  end

  test "assigning a second valid primary is a conflict and set as primary replaces it" do
    party = parties(:unlinked)
    general = create_email_contact!(party, address: "general@example.com", actor: users(:one))
    billing = create_email_contact!(party, address: "billing@example.com", actor: users(:one))

    AssignContactPointPurpose.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      contact_point: general,
      purpose: "general",
      priority: 1
    ).call

    error = assert_raises(MembershipCommand::Error) do
      AssignContactPointPurpose.new(
        agency: agencies(:one),
        actor: users(:one),
        party:,
        contact_point: billing,
        purpose: "general",
        priority: 1
      ).call
    end
    assert_equal :conflict, error.code

    SetContactPointPrimary.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      contact_point: billing,
      purpose: "general"
    ).call

    today = DirectoryDate.today(agencies(:one))
    current = ContactPointPurposeAssignment.current_on(today).primary.where(
      party:,
      contact_kind: "email",
      purpose: "general"
    )
    assert_equal [ billing.id ], current.map(&:contact_point_id)
    original = ContactPointPurposeAssignment.find_by!(contact_point: general, purpose: "general", record_status: "superseded")
    assert_equal current.first.id, original.superseded_by_assignment_id
  end

  test "staff may manage contact points" do
    contact_point = CreatePartyContactPoint.new(
      agency: agencies(:two),
      actor: users(:two),
      party: parties(:two),
      contact_kind: "phone",
      attributes: { display_number: "415-555-0199", phone_type: "mobile", parsed_country_code: "US" }
    ).call.contact_point

    assert_includes %w[valid possible], contact_point.phone_number.parse_status
    assert_equal "415-555-0199", contact_point.phone_number.display_number
  end

  test "audit payloads omit the full email address" do
    CreatePartyContactPoint.new(
      agency: agencies(:one),
      actor: users(:one),
      party: parties(:unlinked),
      contact_kind: "email",
      attributes: { display_address: "secret.inbox@example.com", email_type: "personal" }
    ).call

    event = AuditEvent.order(:created_at).last
    assert_equal "directory.contact_created", event.action
    assert_equal "PartyContactPoint", event.subject_type
    assert_not_includes event.details.to_s, "secret.inbox@example.com"
  end
end
