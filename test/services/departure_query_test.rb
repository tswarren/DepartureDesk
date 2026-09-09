require "test_helper"

class DepartureQueryTest < ActiveSupport::TestCase
  test "upcoming program summaries return one access-filtered aggregate per program" do
    extra = CreateOffice.new(
      agency: agencies(:one),
      actor: users(:one),
      name: "Boston",
      code: "BOS",
      default_timezone: agencies(:one).default_timezone
    ).call.office
    program = create_travel_program!(agencies(:one), actor: users(:one), name: "Atlantic Series")
    empty = create_travel_program!(agencies(:one), actor: users(:one), name: "Empty Series")
    visible = create_departure!(
      agencies(:one),
      actor: users(:staff_one),
      travel_program: program,
      name: "Visible MAIN",
      start_date: Date.new(2027, 8, 1),
      end_date: Date.new(2027, 8, 8)
    )
    create_departure!(
      agencies(:one),
      actor: users(:one),
      office: extra,
      travel_program: program,
      name: "Hidden Boston",
      start_date: Date.new(2027, 7, 20),
      end_date: Date.new(2027, 7, 27)
    )
    create_departure!(
      agencies(:one),
      actor: users(:staff_one),
      travel_program: program,
      name: "Later MAIN",
      start_date: Date.new(2027, 9, 1),
      end_date: Date.new(2027, 9, 8)
    )

    summaries = DepartureQuery.new(
      agency: agencies(:one),
      membership: agency_memberships(:staff_one)
    ).upcoming_program_summaries(
      program_ids: [ program.id, empty.id ],
      on: Date.new(2027, 7, 15)
    )

    assert_equal 2, summaries.fetch(program.id).upcoming_count
    assert_equal visible.start_date, summaries.fetch(program.id).next_start_date
    assert_nil summaries[empty.id]
  end
end
