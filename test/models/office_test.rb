require "test_helper"

class OfficeTest < ActiveSupport::TestCase
  test "codes are unique per agency and reusable across agencies" do
    assert_equal "MAIN", offices(:one).code
    assert_equal "MAIN", offices(:two).code
    assert_not_equal offices(:one).agency_id, offices(:two).agency_id

    error = assert_raises(ActiveRecord::RecordInvalid) do
      agencies(:one).offices.create!(
        name: "Duplicate",
        code: "MAIN",
        status: "active",
        default_timezone: "UTC"
      )
    end
    assert_includes error.message, "Code"
  end

  test "database rejects an invalid office code" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Office.connection.execute(<<~SQL)
        INSERT INTO offices (id, agency_id, name, code, status, default_timezone, lock_version, created_at, updated_at)
        VALUES (
          uuidv7(),
          '#{agencies(:one).id}',
          'Bad Code',
          '1MAIN',
          'active',
          'UTC',
          0,
          CURRENT_TIMESTAMP,
          CURRENT_TIMESTAMP
        )
      SQL
    end
  end

  test "code cannot be changed after create" do
    office = offices(:one)
    office.code = "BOS"

    assert_not office.valid?
    assert_includes office.errors[:code], "cannot be changed"
  end

  test "next MAIN code is collision-safe" do
    assert_equal "MAIN2", Office.next_main_code(agencies(:one))

    agencies(:one).offices.create!(
      name: "Second main",
      code: "MAIN2",
      status: "active",
      default_timezone: agencies(:one).default_timezone
    )

    assert_equal "MAIN3", Office.next_main_code(agencies(:one))
  end

  test "next MAIN code aborts when the next suffix would exceed ten characters" do
    codes = [ "MAIN" ]
    suffix = 2
    loop do
      candidate = "MAIN#{suffix}"
      break if candidate.length > 10

      codes << candidate
      suffix += 1
    end
    taken = Object.new
    taken.define_singleton_method(:where) { |*| taken }
    taken.define_singleton_method(:pluck) { |*| codes }
    agency = agencies(:one)
    agency.define_singleton_method(:offices) { taken }

    error = assert_raises(ArgumentError) { Office.next_main_code(agency) }
    assert_match(/MAIN office code/, error.message)
  end
end
