require "test_helper"

class DepartureCommandsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @other = agencies(:cove)
    @admin = agency_users(:harbor_admin)
    @staff = agency_users(:harbor_staff)
    @baseline_staff = agency_users(:harbor_baseline_staff)
    @other_admin = agency_users(:cove_admin)
  end

  test "create copies actor, agency timezone, and agency currency when omitted, and no office" do
    departure = CreateDeparture.new(
      agency: @agency,
      actor: @admin,
      attributes: { name: "Copied Defaults" }
    ).call.record

    assert_equal "not_on_sale", departure.summary_label
    assert_equal "DEP-0001", departure.departure_reference
    assert_equal [ @admin ], departure.team_members.map(&:agency_user)
    assert_equal @admin, departure.default_task_owner, "the creator starts as default task owner (OPS-12)"
    assert_equal @agency.default_timezone, departure.time_zone
    assert_equal @agency.default_currency, departure.operating_currency
    assert_equal 1, AuditEvent.where(agency: @agency, action: "departure.created", subject_id: departure.id).count
  end

  test "create allows a draft without an office and does not invent one" do
    departure = CreateDeparture.new(
      agency: @agency,
      actor: @admin,
      attributes: { name: "Zero Office" }
    ).call.record

    assert_equal @agency.default_timezone, departure.time_zone
  end

  test "explicit blanks override copied defaults" do
    departure = CreateDeparture.new(
      agency: @agency,
      actor: @admin,
      attributes: {
        name: "Blank Overrides",
        time_zone: "",
        operating_currency: ""
      }
    ).call.record

    assert_nil departure.time_zone
    assert_nil departure.operating_currency
  end

  test "copied timezone is not live inheritance" do
    departure = CreateDeparture.new(
      agency: @agency,
      actor: @admin,
      attributes: { name: "Frozen Zone" }
    ).call.record
    assert_equal "America/New_York", departure.time_zone
    @agency.update!(default_timezone: "America/Chicago")

    assert_equal "America/New_York", departure.reload.time_zone
  end

  test "staff without departure management cannot create and unauthorized writes are not audited" do
    assert_no_difference -> { Departure.count } do
      assert_no_difference -> { AuditEvent.where(action: "departure.created").count } do
        error = assert_raises(AgencyCommand::Error) do
          CreateDeparture.new(agency: @agency, actor: @baseline_staff, attributes: { name: "Viewer Draft" }).call
        end
        assert_equal :unauthorized, error.code
      end
    end
  end

  test "a draft has its reference from creation; activation, return to draft and reactivation keep it (D-91)" do
    departure = create_complete_draft("Caribbean Week")
    assert_equal "DEP-0001", departure.departure_reference
    activated = MarkDepartureReadyToSell.new(agency: @agency, actor: @staff, departure:, lock_version: departure.lock_version).call.record

    assert_equal "on_sale", activated.summary_label
    assert_equal "DEP-0001", activated.departure_reference
    assert_equal 1, AuditEvent.where(agency: @agency, action: "departure.ready_to_sell", subject_id: activated.id).count

    returned = ReturnDepartureToDraft.new(
      agency: @agency, actor: @staff, departure: activated, reason: "Need another date", lock_version: activated.lock_version
    ).call.record
    assert_equal "not_on_sale", returned.summary_label
    assert_equal "DEP-0001", returned.departure_reference
    returned.update!(starts_on: nil, ends_on: nil)
    assert_nil returned.reload.starts_on
    returned.update!(starts_on: Date.new(2026, 6, 1), ends_on: Date.new(2026, 6, 8))

    reactivated = MarkDepartureReadyToSell.new(agency: @agency, actor: @staff, departure: returned, lock_version: returned.lock_version).call.record
    assert_equal "DEP-0001", reactivated.departure_reference
    assert_equal 2, AuditEvent.where(agency: @agency, action: "departure.ready_to_sell", subject_id: reactivated.id).count
  end

  test "lifecycle replay succeeds with a stale lock_version and does not audit" do
    departure = activate_departure!(create_complete_draft("Replay Ship"))
    stale = departure.lock_version - 1

    replay = MarkDepartureReadyToSell.new(agency: @agency, actor: @admin, departure:, lock_version: stale).call
    assert_equal :noop, replay.status
    assert_equal 1, AuditEvent.where(agency: @agency, action: "departure.ready_to_sell", subject_id: departure.id).count

    ReturnDepartureToDraft.new(agency: @agency, actor: @admin, departure:, reason: "pause", lock_version: departure.reload.lock_version).call
    draft_replay = ReturnDepartureToDraft.new(agency: @agency, actor: @admin, departure:, reason: "", lock_version: stale).call
    assert_equal :noop, draft_replay.status
    assert_equal 1, AuditEvent.where(agency: @agency, action: "departure.returned_to_draft", subject_id: departure.id).count
  end

  test "ordinary update no-ops still require a current lock_version" do
    departure = create_complete_draft("Lock Check")
    error = assert_raises(AgencyCommand::Error) do
      UpdateDeparture.new(
        agency: @agency, actor: @admin, departure:,
        attributes: update_attrs(departure),
        lock_version: departure.lock_version - 1
      ).call
    end
    assert_equal :conflict, error.code

    result = UpdateDeparture.new(
      agency: @agency, actor: @admin, departure:,
      attributes: update_attrs(departure),
      lock_version: departure.lock_version
    ).call
    assert_equal :noop, result.status
    assert_equal 0, AuditEvent.where(agency: @agency, action: "departure.updated", subject_id: departure.id).count
  end

  test "updating an active departure cannot clear required operating fields" do
    departure = activate_departure!(create_complete_draft("Active Completeness"))

    {
      "dates" => update_attrs(departure, starts_on: "", ends_on: ""),
      "time zone" => update_attrs(departure, time_zone: ""),
      "operating currency" => update_attrs(departure, operating_currency: "")
    }.each do |field, attributes|
      error = assert_raises(AgencyCommand::Error, "clearing #{field}") do
        UpdateDeparture.new(
          agency: @agency, actor: @admin, departure:,
          attributes:,
          lock_version: departure.lock_version
        ).call
      end
      assert_equal :invalid, error.code, "clearing #{field}"
    end

    departure.reload
    assert_equal Date.new(2026, 6, 1), departure.starts_on
    assert_equal Date.new(2026, 6, 8), departure.ends_on
    assert_equal "America/New_York", departure.time_zone
    assert_equal "USD", departure.operating_currency
    assert_equal 0, AuditEvent.where(agency: @agency, action: "departure.updated", subject_id: departure.id).count
  end

  test "activation blockers list timezone and currency independently" do
    departure = CreateDeparture.new(agency: @agency, actor: @admin, attributes: { name: "Independent Blockers" }).call.record
    Departure.where(id: departure.id).update_all(time_zone: "Not/AZone", operating_currency: nil)
    blockers = departure.reload.ready_to_sell_blockers

    assert_includes blockers, "Enter a recognized time zone."
    assert_includes blockers, "Enter a supported operating currency."
  end

  test "update allows active currency changes and rejects departed date changes" do
    departure = activate_departure!(create_complete_draft("Currency Edit"))
    UpdateDeparture.new(
      agency: @agency, actor: @admin, departure:,
      attributes: update_attrs(departure, operating_currency: "EUR"),
      lock_version: departure.lock_version
    ).call
    assert_equal "EUR", departure.reload.operating_currency

    mark_departed!(departure)
    error = assert_raises(AgencyCommand::Error) do
      UpdateDeparture.new(
        agency: @agency, actor: @admin, departure:,
        attributes: update_attrs(departure, starts_on: Date.new(2026, 7, 1), ends_on: Date.new(2026, 7, 8)),
        lock_version: departure.reload.lock_version
      ).call
    end
    assert_equal :invalid_state, error.code
  end

  test "activation completeness, creation widening, and a missing sequence use documented codes" do
    incomplete = CreateDeparture.new(agency: @agency, actor: @admin, attributes: { name: "Incomplete" }).call.record
    invalid = assert_raises(AgencyCommand::Error) do
      MarkDepartureReadyToSell.new(agency: @agency, actor: @admin, departure: incomplete, lock_version: incomplete.lock_version).call
    end
    assert_equal :invalid, invalid.code

    @agency.reference_sequences.find_by!(namespace: ReferenceSequence::DEPARTURE_NAMESPACE)
      .update!(next_value: ReferenceSequence::EXHAUSTED_AT)
    assert_equal "DEP-1000000", create_complete_draft("Widened").departure_reference

    @agency.reference_sequences.find_by!(namespace: ReferenceSequence::DEPARTURE_NAMESPACE).delete
    integrity = assert_raises(AgencyCommand::Error) { create_complete_draft("Missing Sequence") }
    assert_equal :invalid, integrity.code
    assert_not @agency.departures.exists?(name: "Missing Sequence")
  end

  test "departed rows cannot activate or return to draft" do
    departure = activate_departure!(create_complete_draft("Already Sailed"))
    mark_departed!(departure)
    activate_error = assert_raises(AgencyCommand::Error) do
      MarkDepartureReadyToSell.new(agency: @agency, actor: @admin, departure:, lock_version: departure.lock_version).call
    end
    return_error = assert_raises(AgencyCommand::Error) do
      ReturnDepartureToDraft.new(agency: @agency, actor: @admin, departure:, reason: "undo", lock_version: departure.lock_version).call
    end
    assert_equal :invalid_state, activate_error.code
    assert_equal :invalid_state, return_error.code
  end

  test "the return-to-draft note is optional and identity columns are immutable" do
    departure = activate_departure!(create_complete_draft("Keep Reference"))
    returned = ReturnDepartureToDraft.new(agency: @agency, actor: @admin, departure:, reason: "  ", lock_version: departure.lock_version).call.record
    assert returned.draft?
    assert_nil AuditEvent.where(subject_id: departure.id, action: "departure.returned_to_draft").sole.details["note"]
    departure = activate_departure!(returned)

    identity = assert_raises(ActiveRecord::StatementInvalid) do
      Departure.transaction(requires_new: true) do
        Departure.where(id: departure.id).update_all(departure_reference: "DEP-9999")
      end
    end
    assert_match(/departure identity is immutable/, identity.message)
    agency_change = assert_raises(ActiveRecord::StatementInvalid) do
      Departure.transaction(requires_new: true) do
        Departure.where(id: departure.id).update_all(agency_id: @other.id)
      end
    end
    assert_match(/departure identity is immutable/, agency_change.message)
  end

  test "inactive agency cannot mutate departures" do
    departure = create_complete_draft("Closed Agency")
    @agency.update!(status: "suspended")
    error = assert_raises(AgencyCommand::Error) do
      UpdateDeparture.new(
        agency: @agency, actor: @admin, departure:,
        attributes: update_attrs(departure, name: "Nope"),
        lock_version: departure.lock_version
      ).call
    end
    assert_equal :invalid_state, error.code
  end

  test "cross-agency audit subject is rejected" do
    departure = create_complete_draft("Audit Ownership")
    other = CreateDeparture.new(agency: @other, actor: @other_admin, attributes: { name: "Cove Draft" }).call.record
    assert_raises(AgencyCommand::Error) do
      RecordAdministrativeAudit.record(
        agency: @agency,
        action: "departure.created",
        subject: other,
        actor_agency_user: @admin,
        details: { "departure_id" => other.id }
      )
    end
    event = RecordAdministrativeAudit.record(
      agency: @agency,
      action: "departure.created",
      subject: departure,
      actor_agency_user: @admin,
      details: { "departure_id" => departure.id }
    )
    assert_equal "Departure", event.subject_type
  end

  test "activation needs no team member (ACC-09)" do
    departure = create_complete_draft("No Team")
    RemoveDepartureTeamMember.new(agency: @agency, actor: @admin, departure:, agency_user_id: @admin.id).call
    assert_empty departure.reload.team_members
    assert_empty departure.ready_to_sell_blockers
    assert_equal "on_sale", activate_departure!(departure).summary_label
  end

  test "the team adds staff without departure management, sets one default owner, and audits each change" do
    departure = create_complete_draft("Team Work")

    assert_difference -> { AuditEvent.where(subject_id: departure.id, action: "departure.team_member_added").count }, 1 do
      AddDepartureTeamMember.new(agency: @agency, actor: @admin, departure:, agency_user_id: @baseline_staff.id).call
    end
    replay = AddDepartureTeamMember.new(agency: @agency, actor: @admin, departure:, agency_user_id: @baseline_staff.id).call
    assert_equal :noop, replay.status

    SetDepartureDefaultTaskOwner.new(agency: @agency, actor: @admin, departure:, agency_user_id: @baseline_staff.id).call
    assert_equal @baseline_staff, departure.reload.default_task_owner
    assert_equal 1, departure.team_members.where(default_task_owner: true).count

    SetDepartureDefaultTaskOwner.new(agency: @agency, actor: @admin, departure:, agency_user_id: "").call
    assert_nil departure.reload.default_task_owner

    RemoveDepartureTeamMember.new(agency: @agency, actor: @admin, departure:, agency_user_id: @baseline_staff.id).call
    assert_equal [ @admin ], departure.reload.team_members.map(&:agency_user)
    assert_not @baseline_staff.reload.permitted?(:manage_departures), "membership grants nothing (ACC-09)"
  end

  test "the team refuses reseller, inactive, non-member and other-agency users" do
    departure = create_complete_draft("Team Guards")
    reseller = @agency.resellers.create!(name: "Harbor Partners")
    reseller_user = @agency.agency_users.create!(
      email_address: "partner@example.com", first_name: "Pat", last_name: "Partner", user_type: "reseller",
      reseller:, status: "active", password: TEST_PASSWORD, credential_version: 1
    )
    { reseller_user.id => :invalid, @other_admin.id => :not_found, agency_users(:harbor_suspended).id => :invalid_state }.each do |user_id, code|
      error = assert_raises(AgencyCommand::Error) do
        AddDepartureTeamMember.new(agency: @agency, actor: @admin, departure:, agency_user_id: user_id).call
      end
      assert_equal code, error.code, user_id
    end
    not_member = assert_raises(AgencyCommand::Error) do
      SetDepartureDefaultTaskOwner.new(agency: @agency, actor: @admin, departure:, agency_user_id: @staff.id).call
    end
    assert_equal :not_found, not_member.code
    assert_not_includes @agency.agency_users.agency_staff, reseller_user
  end

  test "staff without departure management cannot change the team, and a departed team is fixed" do
    departure = activate_departure!(create_complete_draft("Team Lock"))
    refused = assert_raises(AgencyCommand::Error) do
      AddDepartureTeamMember.new(agency: @agency, actor: @baseline_staff, departure:, agency_user_id: @baseline_staff.id).call
    end
    assert_equal :unauthorized, refused.code

    mark_departed!(departure)
    departed = assert_raises(AgencyCommand::Error) do
      AddDepartureTeamMember.new(agency: @agency, actor: @admin, departure: departure.reload, agency_user_id: @staff.id).call
    end
    assert_equal :invalid_state, departed.code
  end

  test "composite foreign keys refuse a cross-agency team member" do
    departure = create_complete_draft("FK Guard")
    assert_raises(ActiveRecord::InvalidForeignKey) do
      DepartureTeamMember.transaction(requires_new: true) do
        DepartureTeamMember.insert_all!([ { agency_id: @agency.id, departure_id: departure.id, agency_user_id: @other_admin.id } ])
      end
    end
  end

  private

  def create_complete_draft(name, overrides = {})
    CreateDeparture.new(
      agency: @agency,
      actor: @admin,
      attributes: complete_attrs(name:, **overrides)
    ).call.record
  end

  def activate_departure!(departure)
    MarkDepartureReadyToSell.new(agency: @agency, actor: @admin, departure:, lock_version: departure.lock_version).call.record
  end

  def complete_attrs(overrides = {})
    {
      name: "Eastern Caribbean",
      starts_on: Date.new(2026, 6, 1),
      ends_on: Date.new(2026, 6, 8),
      time_zone: "America/New_York",
      operating_currency: "USD"
    }.merge(overrides)
  end

  def update_attrs(departure, overrides = {})
    {
      name: departure.name,
      description: departure.description,
      starts_on: departure.starts_on,
      ends_on: departure.ends_on,
      time_zone: departure.time_zone,
      operating_currency: departure.operating_currency
    }.merge(overrides)
  end

  def mark_departed!(departure)
    Departure.where(id: departure.id).update_all(completion_status: "departed", departed_at: Time.current, updated_at: Time.current)
    departure.reload
  end
end
