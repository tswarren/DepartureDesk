require "test_helper"

class DepartureCommandsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @other = agencies(:cove)
    @admin = agency_users(:harbor_admin)
    @staff = agency_users(:harbor_staff)
    @viewer = agency_users(:harbor_viewer)
    @office = offices(:harbor_main)
    @west = offices(:harbor_west)
    @other_admin = agency_users(:cove_admin)
    @other_office = offices(:cove_main)
  end

  test "create copies current office, actor, agency timezone, and agency currency when omitted" do
    departure = CreateDeparture.new(
      agency: @agency,
      actor: @admin,
      attributes: { name: "Copied Defaults" },
      current_office: @west
    ).call.record

    assert_equal "draft", departure.status
    assert_nil departure.departure_reference
    assert_equal @west.id, departure.responsible_office_id
    assert_equal @admin.id, departure.responsible_agency_user_id
    assert_equal @agency.default_timezone, departure.time_zone
    assert_not_equal @west.default_timezone, departure.time_zone
    assert_equal @agency.default_currency, departure.operating_currency
    assert_equal 1, AuditEvent.where(agency: @agency, action: "departure.created", subject_id: departure.id).count
  end

  test "create allows a draft without an office and does not invent one" do
    departure = CreateDeparture.new(
      agency: @agency,
      actor: @admin,
      attributes: { name: "Zero Office" },
      current_office: nil
    ).call.record

    assert_nil departure.responsible_office_id
    assert_equal @admin.id, departure.responsible_agency_user_id
    assert_equal @agency.default_timezone, departure.time_zone
  end

  test "explicit blanks override copied defaults" do
    departure = CreateDeparture.new(
      agency: @agency,
      actor: @admin,
      attributes: {
        name: "Blank Overrides",
        responsible_office_id: "",
        responsible_agency_user_id: "",
        time_zone: "",
        operating_currency: ""
      },
      current_office: @office
    ).call.record

    assert_nil departure.responsible_office_id
    assert_nil departure.responsible_agency_user_id
    assert_nil departure.time_zone
    assert_nil departure.operating_currency
  end

  test "copied timezone is not live inheritance" do
    departure = CreateDeparture.new(
      agency: @agency,
      actor: @admin,
      attributes: { name: "Frozen Zone" },
      current_office: @west
    ).call.record
    assert_equal "America/New_York", departure.time_zone
    @agency.update!(default_timezone: "America/Chicago")

    assert_equal "America/New_York", departure.reload.time_zone
  end

  test "create rejects other-agency office as not found and inactive office as invalid_state" do
    not_found = assert_raises(AgencyCommand::Error) do
      CreateDeparture.new(
        agency: @agency,
        actor: @admin,
        attributes: { name: "Foreign Office", responsible_office_id: @other_office.id }
      ).call
    end
    assert_equal :not_found, not_found.code

    ChangeOfficeStatus.new(office: @west, actor: @admin, status: "inactive", lock_version: @west.lock_version).call
    invalid_state = assert_raises(AgencyCommand::Error) do
      CreateDeparture.new(
        agency: @agency,
        actor: @admin,
        attributes: { name: "Inactive Office", responsible_office_id: @west.id }
      ).call
    end
    assert_equal :invalid_state, invalid_state.code
  end

  test "viewer cannot create and unauthorized writes are not audited" do
    assert_no_difference -> { Departure.count } do
      assert_no_difference -> { AuditEvent.where(action: "departure.created").count } do
        error = assert_raises(AgencyCommand::Error) do
          CreateDeparture.new(agency: @agency, actor: @viewer, attributes: { name: "Viewer Draft" }).call
        end
        assert_equal :unauthorized, error.code
      end
    end
  end

  test "activation issues a reference, reactivation reuses it, and return to draft retains it" do
    departure = create_complete_draft("Caribbean Week")
    activated = ActivateDeparture.new(agency: @agency, actor: @staff, departure:, lock_version: departure.lock_version).call.record

    assert_equal "active", activated.status
    assert_equal "D-000001", activated.departure_reference
    first_activated_at = activated.reload.first_activated_at
    assert_not_nil first_activated_at
    assert_equal 1, AuditEvent.where(agency: @agency, action: "departure.activated", subject_id: activated.id).count

    returned = ReturnDepartureToDraft.new(
      agency: @agency, actor: @staff, departure: activated, reason: "Need another date", lock_version: activated.lock_version
    ).call.record
    assert_equal "draft", returned.status
    assert_equal "D-000001", returned.departure_reference
    assert_equal first_activated_at, returned.first_activated_at
    returned.update!(starts_on: nil, ends_on: nil)
    assert_nil returned.reload.starts_on
    returned.update!(starts_on: Date.new(2026, 6, 1), ends_on: Date.new(2026, 6, 8))

    reactivated = ActivateDeparture.new(agency: @agency, actor: @staff, departure: returned, lock_version: returned.lock_version).call.record
    assert_equal "D-000001", reactivated.departure_reference
    assert_equal first_activated_at, reactivated.first_activated_at
    assert_equal 2, AuditEvent.where(agency: @agency, action: "departure.activated", subject_id: reactivated.id).count
  end

  test "lifecycle replay succeeds with a stale lock_version and does not audit" do
    departure = activate_departure!(create_complete_draft("Replay Ship"))
    stale = departure.lock_version - 1

    replay = ActivateDeparture.new(agency: @agency, actor: @admin, departure:, lock_version: stale).call
    assert_equal :noop, replay.status
    assert_equal 1, AuditEvent.where(agency: @agency, action: "departure.activated", subject_id: departure.id).count

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
    blockers = departure.reload.activation_blockers

    assert_includes blockers, "Enter a recognized time zone."
    assert_includes blockers, "Enter a supported operating currency."
  end

  test "office inactivation before activation rejects activation" do
    departure = create_complete_draft("Office First")
    ChangeOfficeStatus.new(office: @office, actor: @admin, status: "inactive", lock_version: @office.lock_version).call

    error = assert_raises(AgencyCommand::Error) do
      ActivateDeparture.new(agency: @agency, actor: @admin, departure:, lock_version: departure.lock_version).call
    end
    assert_equal :invalid_state, error.code
    assert_equal "draft", departure.reload.status
    assert_nil departure.departure_reference
    assert_equal "inactive", @office.reload.status
  end

  test "office inactivation after activation leaves historical inactive responsibility" do
    departure = activate_departure!(create_complete_draft("Activate First"))
    ChangeOfficeStatus.new(office: @office, actor: @admin, status: "inactive", lock_version: @office.lock_version).call

    departure.reload
    assert_equal "active", departure.status
    assert_equal "D-000001", departure.departure_reference
    assert_equal @office.id, departure.responsible_office_id
    assert_equal "inactive", @office.reload.status
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

  test "responsibility accepts a viewer, rejects inactive replacements, and retains historical inactive targets" do
    departure = create_complete_draft("Responsibility")
    UpdateDepartureResponsibility.new(
      agency: @agency, actor: @admin, departure:,
      office_id: @office.id, agency_user_id: @viewer.id, lock_version: departure.lock_version
    ).call
    assert_equal @viewer.id, departure.reload.responsible_agency_user_id

    ChangeOfficeStatus.new(office: @west, actor: @admin, status: "inactive", lock_version: @west.lock_version).call
    inactive = assert_raises(AgencyCommand::Error) do
      UpdateDepartureResponsibility.new(
        agency: @agency, actor: @admin, departure:,
        office_id: @west.id, agency_user_id: @viewer.id, lock_version: departure.lock_version
      ).call
    end
    assert_equal :invalid_state, inactive.code

    UpdateDepartureResponsibility.new(
      agency: @agency, actor: @admin, departure:,
      office_id: @office.id, agency_user_id: @viewer.id, lock_version: departure.lock_version
    ).call
    ChangeOfficeStatus.new(office: @office, actor: @admin, status: "inactive", lock_version: @office.reload.lock_version).call
    assert_equal @office.id, departure.reload.responsible_office_id
  end

  test "activation completeness, exhaustion, and missing sequence use documented codes" do
    incomplete = CreateDeparture.new(agency: @agency, actor: @admin, attributes: { name: "Incomplete" }).call.record
    invalid = assert_raises(AgencyCommand::Error) do
      ActivateDeparture.new(agency: @agency, actor: @admin, departure: incomplete, lock_version: incomplete.lock_version).call
    end
    assert_equal :invalid, invalid.code

    departure = create_complete_draft("Exhausted")
    @agency.reference_sequences.find_by!(namespace: ReferenceSequence::DEPARTURE_NAMESPACE)
      .update!(next_value: ReferenceSequence::EXHAUSTED_AT)
    exhausted = assert_raises(AgencyCommand::Error) do
      ActivateDeparture.new(agency: @agency, actor: @admin, departure:, lock_version: departure.lock_version).call
    end
    assert_equal :reference_exhausted, exhausted.code

    missing = create_complete_draft("Missing Sequence")
    @agency.reference_sequences.find_by!(namespace: ReferenceSequence::DEPARTURE_NAMESPACE).delete
    integrity = assert_raises(AgencyCommand::Error) do
      ActivateDeparture.new(agency: @agency, actor: @admin, departure: missing, lock_version: missing.lock_version).call
    end
    assert_equal :invalid, integrity.code
  end

  test "departed rows cannot activate or return to draft" do
    departure = activate_departure!(create_complete_draft("Already Sailed"))
    mark_departed!(departure)
    activate_error = assert_raises(AgencyCommand::Error) do
      ActivateDeparture.new(agency: @agency, actor: @admin, departure:, lock_version: departure.lock_version).call
    end
    return_error = assert_raises(AgencyCommand::Error) do
      ReturnDepartureToDraft.new(agency: @agency, actor: @admin, departure:, reason: "undo", lock_version: departure.lock_version).call
    end
    assert_equal :invalid_state, activate_error.code
    assert_equal :invalid_state, return_error.code
  end

  test "blank return reason is invalid and identity columns are immutable" do
    departure = activate_departure!(create_complete_draft("Keep Reference"))
    blank = assert_raises(AgencyCommand::Error) do
      ReturnDepartureToDraft.new(agency: @agency, actor: @admin, departure:, reason: "  ", lock_version: departure.lock_version).call
    end
    assert_equal :invalid, blank.code

    identity = assert_raises(ActiveRecord::StatementInvalid) do
      Departure.transaction(requires_new: true) do
        Departure.where(id: departure.id).update_all(departure_reference: "D-999999")
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

  test "composite foreign keys reject cross-agency office and user assignment" do
    departure = create_complete_draft("FK Guard")
    assert_raises(ActiveRecord::InvalidForeignKey) do
      Departure.transaction(requires_new: true) do
        Departure.where(id: departure.id).update_all(responsible_office_id: @other_office.id)
      end
    end
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

  private

  def create_complete_draft(name)
    CreateDeparture.new(
      agency: @agency,
      actor: @admin,
      attributes: complete_attrs(name:),
      current_office: @office
    ).call.record
  end

  def activate_departure!(departure)
    ActivateDeparture.new(agency: @agency, actor: @admin, departure:, lock_version: departure.lock_version).call.record
  end

  def complete_attrs(overrides = {})
    {
      name: "Eastern Caribbean",
      starts_on: Date.new(2026, 6, 1),
      ends_on: Date.new(2026, 6, 8),
      time_zone: "America/New_York",
      operating_currency: "USD",
      responsible_office_id: @office.id,
      responsible_agency_user_id: @admin.id
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
    Departure.where(id: departure.id).update_all(status: "departed", departed_at: Time.current, updated_at: Time.current)
    departure.reload
  end
end
