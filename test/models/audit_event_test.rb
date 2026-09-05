require "test_helper"

class AuditEventTest < ActiveSupport::TestCase
  test "accepts a well-formed application action" do
    event = RecordAdministrativeAudit.record(
      agency: agencies(:one),
      action: "agency.profile_updated",
      actor_user: users(:one),
      subject: agencies(:one),
      details: { "changed_fields" => [ "name" ] }
    )

    assert event.persisted?
    assert_equal "user", event.actor_kind
    assert_nil event.actor_identifier
  end

  test "rejects an unknown action in the model" do
    event = AuditEvent.new(
      agency: agencies(:one),
      actor_kind: "user",
      actor_user: users(:one),
      action: "agency.not_a_real_action",
      subject_type: "Agency",
      subject_id: agencies(:one).id
    )

    assert_not event.valid?
    assert_includes event.errors[:action], "is not included in the list"
  end

  test "rejects a malformed action in the database" do
    event = AuditEvent.new(
      agency: agencies(:one),
      actor_kind: "user",
      actor_user: users(:one),
      action: "agency.profile_updated",
      subject_type: "Agency",
      subject_id: agencies(:one).id,
      details: {},
      created_at: Time.current
    )
    event.write_attribute(:action, "PROFILE-UPDATED")

    assert_raises(ActiveRecord::StatementInvalid) do
      AuditEvent.transaction(requires_new: true) do
        event.save!(validate: false)
      end
    end
  end

  test "rejects updates in the model" do
    event = RecordAdministrativeAudit.record(
      agency: agencies(:one),
      action: "agency.profile_updated",
      actor_user: users(:one),
      subject: agencies(:one)
    )

    assert_not event.update(details: { "changed" => true })
    assert_includes event.errors[:base], "audit events are append-only"
  end

  test "rejects destroys in the model" do
    event = RecordAdministrativeAudit.record(
      agency: agencies(:one),
      action: "agency.profile_updated",
      actor_user: users(:one),
      subject: agencies(:one)
    )

    assert_not event.destroy
    assert AuditEvent.exists?(event.id)
  end

  test "rejects updates in the database" do
    event = RecordAdministrativeAudit.record(
      agency: agencies(:one),
      action: "agency.profile_updated",
      actor_user: users(:one),
      subject: agencies(:one)
    )

    assert_raises(ActiveRecord::StatementInvalid) do
      AuditEvent.transaction(requires_new: true) do
        AuditEvent.connection.execute(
          "UPDATE audit_events SET details = '{}'::jsonb WHERE id = '#{event.id}'"
        )
      end
    end
  end

  test "rejects deletes in the database" do
    event = RecordAdministrativeAudit.record(
      agency: agencies(:one),
      action: "agency.profile_updated",
      actor_user: users(:one),
      subject: agencies(:one)
    )

    assert_raises(ActiveRecord::StatementInvalid) do
      AuditEvent.transaction(requires_new: true) do
        AuditEvent.connection.execute(
          "DELETE FROM audit_events WHERE id = '#{event.id}'"
        )
      end
    end
  end

  test "requires a system actor identifier without a user" do
    event = AuditEvent.new(
      agency: agencies(:one),
      actor_kind: "system",
      actor_identifier: "operator:deploy",
      action: "agency.profile_updated",
      subject_type: "Agency",
      subject_id: agencies(:one).id,
      details: {},
      created_at: Time.current
    )

    assert event.valid?
  end

  test "refuses a system audit without an actor identifier" do
    assert_raises(ArgumentError) do
      RecordAdministrativeAudit.record(
        agency: agencies(:one),
        action: "agency.profile_updated",
        subject: agencies(:one)
      )
    end
  end

  test "rejects an agency subject that is not the event agency" do
    assert_raises(ArgumentError) do
      RecordAdministrativeAudit.record(
        agency: agencies(:one),
        action: "agency.profile_updated",
        actor_user: users(:one),
        subject: agencies(:two)
      )
    end
  end

  test "rejects a membership subject that does not belong to the event agency" do
    assert_raises(ArgumentError) do
      RecordAdministrativeAudit.record(
        agency: agencies(:one),
        action: "team.role_changed",
        actor_user: users(:one),
        subject: agency_memberships(:two)
      )
    end
  end
end
