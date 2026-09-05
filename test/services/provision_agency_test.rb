require "test_helper"

class ProvisionAgencyTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "creates an invited administrator and system-attributed audits" do
    result = nil

    assert_enqueued_emails 1 do
      result = provision
    end

    assert_not result.reused
    assert result.agency.active?
    assert result.membership.invited?
    assert result.membership.administrator?
    assert_nil result.membership.user.usable_agency_membership

    events = result.agency.audit_events.order(:created_at)
    assert_equal %w[agency.provisioned team.invitation_created], events.map(&:action)
    events.each do |event|
      assert_equal "system", event.actor_kind
      assert_equal "ops:test", event.actor_identifier
      assert_nil event.actor_user_id
    end
  end

  test "invalid input leaves no provisioning artifacts" do
    assert_no_difference %w[Agency.count AgencyProvisioningRequest.count User.count AuditEvent.count] do
      assert_no_enqueued_emails do
        error = assert_raises(ProvisionAgency::Error) do
          provision(name: "")
        end
        assert_equal :invalid, error.code
      end
    end
  end

  test "same key and intent returns the existing result without another email" do
    first = provision(key: "same-key", email: "repeat@example.com", name: "Repeat Travel")

    assert_no_difference %w[Agency.count AgencyProvisioningRequest.count AgencyMembership.count] do
      assert_no_enqueued_emails do
        second = provision(key: "same-key", email: "repeat@example.com", name: "Repeat Travel")
        assert second.reused
        assert_equal first.agency.id, second.agency.id
        assert_equal first.membership.id, second.membership.id
      end
    end
  end

  test "same key and different intent conflicts" do
    provision(key: "shared-key", email: "shared-key@example.com", name: "Shared Key Travel")

    assert_no_difference("Agency.count") do
      error = assert_raises(ProvisionAgency::Error) do
        provision(key: "shared-key", email: "other-admin@example.com", name: "Different Travel")
      end
      assert_equal :idempotency_conflict, error.code
    end
  end

  test "new key and duplicate business input conflicts" do
    provision(key: "first-key", email: "duplicate-intent@example.com", name: "Duplicate Intent Travel")

    assert_no_difference("Agency.count") do
      error = assert_raises(ProvisionAgency::Error) do
        provision(key: "second-key", email: "duplicate-intent@example.com", name: "Duplicate Intent Travel")
      end
      assert_equal :idempotency_conflict, error.code
    end
  end

  test "active membership elsewhere is a generic conflict" do
    assert_no_difference %w[Agency.count AgencyProvisioningRequest.count] do
      error = assert_raises(ProvisionAgency::Error) do
        provision(email: users(:one).email_address)
      end
      assert_equal :conflict, error.code
      assert_equal "The initial administrator cannot be provisioned.", error.message
    end
  end

  private

  def provision(key: SecureRandom.hex(8), email: "admin-#{SecureRandom.hex(4)}@example.com", name: "Provisioned #{SecureRandom.hex(4)}", **overrides)
    ProvisionAgency.new(
      idempotency_key: key,
      actor_identifier: "ops:test",
      name: name,
      email: email,
      first_name: "Morgan",
      last_name: "Lee",
      **overrides
    ).call
  end
end
