require "test_helper"

class PartyContactPointTest < ActiveSupport::TestCase
  test "typed detail foreign keys reject a kind mismatch" do
    contact_point = create_email_contact!(parties(:unlinked), address: "kind-mismatch@example.com", actor: users(:one))
    now = Time.current

    assert_raises(ActiveRecord::InvalidForeignKey) do
      PartyPostalAddress.transaction(requires_new: true) do
        PartyPostalAddress.insert_all!([ {
          contact_point_id: contact_point.id,
          agency_id: contact_point.agency_id,
          contact_kind: "postal_address",
          address_line_1: "1 Harbor Way",
          country_code: "US",
          formatted_address: "1 Harbor Way\nUnited States",
          normalized_address: "1 harbor way united states",
          created_at: now,
          updated_at: now
        } ])
      end
    end
  end

  test "suppression metadata must be complete in the database" do
    contact_point = create_email_contact!(parties(:unlinked), address: "suppress-check@example.com", actor: users(:one))

    assert_raises(ActiveRecord::StatementInvalid) do
      PartyContactPoint.transaction(requires_new: true) do
        PartyContactPoint.connection.execute(
          "UPDATE party_contact_points SET suppressed_at = CURRENT_TIMESTAMP WHERE id = '#{contact_point.id}'"
        )
      end
    end
  end

  test "deactivation metadata must match status in the database" do
    contact_point = create_email_contact!(parties(:unlinked), address: "deactivate-check@example.com", actor: users(:one))

    assert_raises(ActiveRecord::StatementInvalid) do
      PartyContactPoint.transaction(requires_new: true) do
        PartyContactPoint.connection.execute(
          "UPDATE party_contact_points SET status = 'deactivated' WHERE id = '#{contact_point.id}'"
        )
      end
    end
  end

  test "overlapping valid priority-one assignments are rejected" do
    contact_point = create_email_contact!(parties(:unlinked), address: "primary-a@example.com", actor: users(:one))
    other = create_email_contact!(parties(:unlinked), address: "primary-b@example.com", actor: users(:one))
    from = DirectoryDate.today(agencies(:one))
    now = Time.current

    ContactPointPurposeAssignment.create!(
      agency: agencies(:one),
      party: parties(:unlinked),
      contact_point:,
      contact_kind: "email",
      purpose: "general",
      priority: 1,
      effective_from: from,
      record_status: "valid"
    )

    assert_raises(ActiveRecord::StatementInvalid) do
      ContactPointPurposeAssignment.transaction(requires_new: true) do
        ContactPointPurposeAssignment.insert_all!([ {
          agency_id: agencies(:one).id,
          party_id: parties(:unlinked).id,
          contact_point_id: other.id,
          contact_kind: "email",
          purpose: "general",
          priority: 1,
          effective_from: from,
          record_status: "valid",
          created_at: now,
          updated_at: now
        } ])
      end
    end
  end

  test "lower-priority assignments may overlap a primary" do
    contact_point = create_email_contact!(parties(:unlinked), address: "priority-one@example.com", actor: users(:one))
    other = create_email_contact!(parties(:unlinked), address: "priority-two@example.com", actor: users(:one))
    from = DirectoryDate.today(agencies(:one))

    ContactPointPurposeAssignment.create!(
      agency: agencies(:one),
      party: parties(:unlinked),
      contact_point:,
      contact_kind: "email",
      purpose: "general",
      priority: 1,
      effective_from: from,
      record_status: "valid"
    )

    alternative = ContactPointPurposeAssignment.create!(
      agency: agencies(:one),
      party: parties(:unlinked),
      contact_point: other,
      contact_kind: "email",
      purpose: "general",
      priority: 2,
      effective_from: from,
      record_status: "valid"
    )

    assert alternative.record_valid?
    assert_equal 2, alternative.priority
  end

  test "superseded rows do not participate in the primary exclusion" do
    contact_point = create_email_contact!(parties(:unlinked), address: "supersede-a@example.com", actor: users(:one))
    other = create_email_contact!(parties(:unlinked), address: "supersede-b@example.com", actor: users(:one))
    from = DirectoryDate.today(agencies(:one))
    original = ContactPointPurposeAssignment.create!(
      agency: agencies(:one),
      party: parties(:unlinked),
      contact_point:,
      contact_kind: "email",
      purpose: "billing",
      priority: 99,
      effective_from: from,
      record_status: "valid"
    )
    replacement = ContactPointPurposeAssignment.create!(
      agency: agencies(:one),
      party: parties(:unlinked),
      contact_point: other,
      contact_kind: "email",
      purpose: "billing",
      priority: 1,
      effective_from: from,
      record_status: "valid"
    )
    original.update!(
      record_status: "superseded",
      superseded_by_assignment: replacement,
      corrected_at: Time.current,
      corrected_by_membership: agency_memberships(:one),
      correction_reason: "Mistaken primary"
    )

    assert replacement.record_valid?
    assert original.record_superseded?
  end

  test "purpose assignment supersession cannot cross agencies" do
    from = DirectoryDate.today(agencies(:one))
    now = Time.current
    local = create_email_contact!(parties(:unlinked), address: "local-purpose@example.com", actor: users(:one))
    foreign = create_email_contact!(parties(:two), address: "foreign-purpose@example.com", actor: users(:two))
    local_assignment = ContactPointPurposeAssignment.create!(
      agency: agencies(:one),
      party: parties(:unlinked),
      contact_point: local,
      contact_kind: "email",
      purpose: "general",
      priority: 1,
      effective_from: from,
      record_status: "valid"
    )
    foreign_assignment = ContactPointPurposeAssignment.create!(
      agency: agencies(:two),
      party: parties(:two),
      contact_point: foreign,
      contact_kind: "email",
      purpose: "general",
      priority: 1,
      effective_from: DirectoryDate.today(agencies(:two)),
      record_status: "valid"
    )

    assert_raises(ActiveRecord::InvalidForeignKey) do
      ContactPointPurposeAssignment.transaction(requires_new: true) do
        ContactPointPurposeAssignment.insert_all!([ {
          agency_id: agencies(:one).id,
          party_id: parties(:unlinked).id,
          contact_point_id: local.id,
          contact_kind: "email",
          purpose: "billing",
          priority: 2,
          effective_from: from,
          record_status: "superseded",
          superseded_by_assignment_id: foreign_assignment.id,
          corrected_at: now,
          corrected_by_membership_id: agency_memberships(:one).id,
          correction_reason: "Cross-agency",
          created_at: now,
          updated_at: now
        } ])
      end
    end
    assert local_assignment.reload.record_valid?
  end

  test "purpose assignments cannot name a party that does not own the contact point" do
    contact_point = create_email_contact!(parties(:unlinked), address: "owner-mismatch@example.com", actor: users(:one))
    now = Time.current

    assert_raises(ActiveRecord::InvalidForeignKey) do
      ContactPointPurposeAssignment.transaction(requires_new: true) do
        ContactPointPurposeAssignment.insert_all!([ {
          agency_id: agencies(:one).id,
          party_id: parties(:one).id,
          contact_point_id: contact_point.id,
          contact_kind: "email",
          purpose: "general",
          priority: 1,
          effective_from: DirectoryDate.today(agencies(:one)),
          record_status: "valid",
          created_at: now,
          updated_at: now
        } ])
      end
    end
  end
end
