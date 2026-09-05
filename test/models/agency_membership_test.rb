require "test_helper"

class AgencyMembershipTest < ActiveSupport::TestCase
  test "accepts a staff membership" do
    membership = AgencyMembership.new(
      user: users(:one),
      agency: agencies(:two),
      role: "staff",
      status: "suspended"
    )

    assert membership.valid?
  end

  test "accepts an administrator membership" do
    membership = agency_memberships(:one)

    assert membership.administrator?
    assert membership.valid?
  end

  test "assigns a UUIDv7 before persistence" do
    membership = AgencyMembership.new(
      user: users(:one),
      agency: agencies(:two),
      role: "staff",
      status: "suspended"
    )

    assert membership.id.present?
    assert membership.id.split("-").fetch(2).start_with?("7")
    assert_not membership.persisted?
  end

  test "preserves its preassigned ID after creation" do
    membership = AgencyMembership.new(
      user: users(:one),
      agency: agencies(:two),
      role: "staff",
      status: "suspended"
    )
    original_id = membership.id

    membership.save!

    assert_equal original_id, membership.reload.id
  end

  test "rejects an invalid role in the model" do
    membership = AgencyMembership.new(
      user: users(:one),
      agency: agencies(:two),
      status: "suspended"
    )
    membership.role = "owner"

    assert_not membership.valid?
    assert_includes membership.errors[:role], "is not included in the list"
  end

  test "rejects an invalid status in the model" do
    membership = AgencyMembership.new(
      user: users(:one),
      agency: agencies(:two),
      role: "staff"
    )
    membership.status = "closed"

    assert_not membership.valid?
    assert_includes membership.errors[:status], "is not included in the list"
  end

  test "rejects an invalid role in the database" do
    membership = AgencyMembership.new(
      user: users(:one),
      agency: agencies(:two),
      role: "staff",
      status: "suspended"
    )
    membership.write_attribute(:role, "owner")

    assert_raises(ActiveRecord::StatementInvalid) do
      AgencyMembership.transaction(requires_new: true) do
        membership.save!(validate: false)
      end
    end
  end

  test "rejects an invalid status in the database" do
    membership = AgencyMembership.new(
      user: users(:one),
      agency: agencies(:two),
      role: "staff",
      status: "active"
    )
    membership.write_attribute(:status, "closed")

    assert_raises(ActiveRecord::StatementInvalid) do
      AgencyMembership.transaction(requires_new: true) do
        membership.save!(validate: false)
      end
    end
  end

  test "rejects a duplicate user and agency pair in the model" do
    membership = AgencyMembership.new(
      user: users(:one),
      agency: agencies(:one),
      role: "staff",
      status: "suspended"
    )

    assert_not membership.valid?
    assert membership.errors[:user_id].any?
  end

  test "rejects a duplicate user and agency pair in the database" do
    membership = AgencyMembership.new(
      user: users(:one),
      agency: agencies(:one),
      role: "staff",
      status: "suspended"
    )

    assert_raises(ActiveRecord::RecordNotUnique) do
      AgencyMembership.transaction(requires_new: true) do
        membership.save!(validate: false)
      end
    end
  end

  test "rejects a second active membership for one user in the model" do
    membership = AgencyMembership.new(
      user: users(:one),
      agency: agencies(:two),
      role: "staff",
      status: "active"
    )

    assert_not membership.valid?
    assert_includes membership.errors[:user_id],
      "already has an active agency membership"
  end

  test "rejects a second active membership for one user in the database" do
    membership = AgencyMembership.new(
      user: users(:one),
      agency: agencies(:two),
      role: "staff",
      status: "active"
    )

    assert_raises(ActiveRecord::RecordNotUnique) do
      AgencyMembership.transaction(requires_new: true) do
        membership.save!(validate: false)
      end
    end
  end

  test "allows one active membership and one suspended historical membership" do
    membership = AgencyMembership.create!(
      user: users(:one),
      agency: agencies(:two),
      role: "staff",
      status: "suspended"
    )

    assert membership.persisted?
    assert_equal 1, users(:one).active_agency_memberships.count
  end

  test "allows multiple suspended memberships for different agencies" do
    user = User.create!(
      email_address: "suspended-history@example.com",
      password: "password",
      password_confirmation: "password"
    )

    AgencyMembership.create!(
      user: user,
      agency: agencies(:one),
      role: "staff",
      status: "suspended"
    )
    AgencyMembership.create!(
      user: user,
      agency: agencies(:two),
      role: "administrator",
      status: "suspended"
    )

    assert_equal 2, user.agency_memberships.suspended.count
    assert_nil user.usable_agency_membership
  end

  test "rejects a missing foreign key in the database" do
    membership = AgencyMembership.new(
      user_id: SecureRandom.uuid_v7,
      agency: agencies(:one),
      role: "staff",
      status: "active"
    )

    assert_raises(ActiveRecord::InvalidForeignKey) do
      AgencyMembership.transaction(requires_new: true) do
        membership.save!(validate: false)
      end
    end
  end

  test "raises on a stale optimistic lock" do
    membership = agency_memberships(:one)
    stale = AgencyMembership.find(membership.id)

    membership.update!(role: "staff")

    assert_raises(ActiveRecord::StaleObjectError) do
      stale.update!(status: "suspended")
    end
  end

  test "does not silently erase memberships when an agency is destroyed" do
    assert_raises(ActiveRecord::DeleteRestrictionError) do
      agencies(:one).destroy!
    end

    assert AgencyMembership.exists?(agency_memberships(:one).id)
  end

  test "does not silently erase memberships when a user is destroyed" do
    assert_raises(ActiveRecord::DeleteRestrictionError) do
      users(:one).destroy!
    end

    assert AgencyMembership.exists?(agency_memberships(:one).id)
  end
end
