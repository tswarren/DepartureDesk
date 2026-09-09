require "test_helper"

class DepartureTest < ActiveSupport::TestCase
  test "status check permits only draft, planning, and cancelled" do
    departure = create_departure!(agencies(:one), actor: users(:one))

    assert departure.draft?
    departure.status = "open_for_sale"
    assert_not departure.valid?
    assert_includes departure.errors[:status], "is not included in the list"
  end

  test "database rejects an unimplemented status" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Departure.transaction(requires_new: true) do
        Departure.insert_all!([ departure_row.merge(status: "open_for_sale") ])
      end
    end
  end

  test "database rejects a malformed reference" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Departure.transaction(requires_new: true) do
        Departure.insert_all!([ departure_row.merge(departure_reference: "MAIN-1") ])
      end
    end
  end

  test "database rejects inverted dates" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Departure.transaction(requires_new: true) do
        Departure.insert_all!([
          departure_row.merge(
            start_date: Date.new(2027, 7, 19),
            end_date: Date.new(2027, 7, 12)
          )
        ])
      end
    end
  end

  test "nonterminal rows require an active owning-office projection" do
    row = departure_row
    assert_raises(ActiveRecord::StatementInvalid) do
      Departure.transaction(requires_new: true) do
        Departure.connection.execute(<<~SQL)
          INSERT INTO departures (
            id, agency_id, office_id, owning_office_status, departure_reference,
            creation_idempotency_key, name, start_date, end_date, default_currency,
            status, created_by_membership_id, status_changed_at, status_changed_by_membership_id,
            lock_version, created_at, updated_at
          ) VALUES (
            '#{row[:id]}', '#{row[:agency_id]}', '#{row[:office_id]}', NULL,
            '#{row[:departure_reference]}', '#{row[:creation_idempotency_key]}',
            '#{row[:name]}', '#{row[:start_date]}', '#{row[:end_date]}',
            '#{row[:default_currency]}', 'draft', '#{row[:created_by_membership_id]}',
            CURRENT_TIMESTAMP, '#{row[:status_changed_by_membership_id]}', 0,
            CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
          )
        SQL
      end
    end
  end

  test "cancelled rows must null the owning-office projection" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Departure.transaction(requires_new: true) do
        Departure.insert_all!([
          departure_row.merge(
            status: "cancelled",
            status_reason: "Withdrawn",
            owning_office_status: "active"
          )
        ])
      end
    end
  end

  test "cross-agency office ownership is rejected at the database" do
    assert_raises(ActiveRecord::InvalidForeignKey) do
      Departure.transaction(requires_new: true) do
        Departure.insert_all!([ departure_row.merge(office_id: offices(:two).id) ])
      end
    end
  end

  test "idempotency keys are unique within an agency and reusable across agencies" do
    key = SecureRandom.uuid
    create_departure!(agencies(:one), actor: users(:one), creation_idempotency_key: key)
    create_departure!(agencies(:two), actor: users(:two), creation_idempotency_key: key)

    assert_raises(ActiveRecord::RecordNotUnique) do
      Departure.transaction(requires_new: true) do
        Departure.insert_all!([ departure_row.merge(creation_idempotency_key: key) ])
      end
    end
  end

  test "program projection requires an active program while nonterminal" do
    program = create_travel_program!(agencies(:one), actor: users(:one))
    row = departure_row

    assert_raises(ActiveRecord::StatementInvalid) do
      Departure.transaction(requires_new: true) do
        Departure.connection.execute(<<~SQL)
          INSERT INTO departures (
            id, agency_id, office_id, owning_office_status, travel_program_id,
            travel_program_status, departure_reference, creation_idempotency_key,
            name, start_date, end_date, default_currency, status,
            created_by_membership_id, status_changed_at, status_changed_by_membership_id,
            lock_version, created_at, updated_at
          ) VALUES (
            '#{row[:id]}', '#{row[:agency_id]}', '#{row[:office_id]}', 'active',
            '#{program.id}', NULL, '#{row[:departure_reference]}',
            '#{row[:creation_idempotency_key]}', '#{row[:name]}',
            '#{row[:start_date]}', '#{row[:end_date]}', '#{row[:default_currency]}',
            'draft', '#{row[:created_by_membership_id]}', CURRENT_TIMESTAMP,
            '#{row[:status_changed_by_membership_id]}', 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
          )
        SQL
      end
    end
  end

  private

  def departure_row
    now = Time.current
    {
      id: SecureRandom.uuid_v7(extra_timestamp_bits: 12),
      agency_id: agencies(:one).id,
      office_id: offices(:one).id,
      owning_office_status: "active",
      departure_reference: "D-999001",
      creation_idempotency_key: SecureRandom.uuid,
      name: "Constraint Departure",
      start_date: Date.new(2027, 7, 12),
      end_date: Date.new(2027, 7, 19),
      default_currency: "USD",
      status: "draft",
      created_by_membership_id: agency_memberships(:one).id,
      status_changed_at: now,
      status_changed_by_membership_id: agency_memberships(:one).id,
      lock_version: 0,
      created_at: now,
      updated_at: now
    }
  end
end
