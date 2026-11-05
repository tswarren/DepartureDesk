require "test_helper"

# DEP-03, DEP-04, DEP-05, D-79, D-86: three statuses and the derived label.
class DepartureStatusesTest < ActiveSupport::TestCase
  # [sales, decision, completion] => label, per the spec's summary label table.
  LABELS = {
    %w[draft undecided active] => "not_on_sale",
    %w[draft proceed active] => "not_on_sale",
    %w[ready_to_sell undecided active] => "on_sale",
    %w[ready_to_sell proceed active] => "on_sale",
    %w[ready_to_sell postpone active] => "postponed",
    %w[draft postpone active] => "postponed",
    %w[ready_to_sell cancel active] => "cancelling",
    %w[draft cancel active] => "cancelling",
    %w[ready_to_sell proceed departed] => "departed",
    %w[ready_to_sell cancel cancelled] => "cancelled",
    %w[ready_to_sell postpone superseded] => "superseded"
  }.freeze

  test "a new Departure is Draft, Undecided and Active, labelled Not on sale" do
    departure = agencies(:harbor).departures.new(name: "New")
    assert departure.sales_draft?
    assert departure.decision_undecided?
    assert departure.completion_active?
    assert_equal "Not on sale", departure.summary_label_text
  end

  test "the summary label follows the spec's table, completion first" do
    LABELS.each do |(sales, decision, completion), label|
      departure = Departure.new(sales_status: sales, operating_decision: decision, completion_status: completion)
      assert_equal label, departure.summary_label, [ sales, decision, completion ].inspect
      assert_equal Departure::SUMMARY_LABELS.fetch(label), departure.summary_label_text
    end
  end

  test "on sale only when Ready to sell, Undecided or Proceed, and Active (DEP-05)" do
    LABELS.each_key do |sales, decision, completion|
      departure = Departure.new(sales_status: sales, operating_decision: decision, completion_status: completion)
      expected = sales == "ready_to_sell" && %w[undecided proceed].include?(decision) && completion == "active"
      assert_equal expected, departure.on_sale?, [ sales, decision, completion ].inspect
    end
  end

  test "the label filter and on_sale scope match the methods for every combination" do
    agency = agencies(:harbor)
    user = agency_users(:harbor_admin)
    rows = LABELS.keys.each_with_index.map do |(sales, decision, completion), index|
      complete = sales == "ready_to_sell" || completion != "active"
      agency.departures.create!(
        name: "Label #{index}", starts_on: Date.new(2027, 1, 1), ends_on: Date.new(2027, 1, 8),
        time_zone: "UTC", operating_currency: "USD", responsible_agency_user: user,
        sales_status: sales, operating_decision: decision, completion_status: completion,
        departure_reference: (format("DEP-%04d", 9000 + index) if complete),
        first_activated_at: (Time.current if complete),
        departed_at: (Time.current if completion == "departed")
      )
    end

    Departure::SUMMARY_LABELS.each_key do |label|
      expected = rows.select { |row| row.summary_label == label }.map(&:id).sort
      assert_equal expected, agency.departures.with_summary_label(label).where(id: rows.map(&:id)).pluck(:id).sort, label
    end
    assert_equal rows.select(&:on_sale?).map(&:id).sort, agency.departures.on_sale.where(id: rows.map(&:id)).pluck(:id).sort
  end

  test "the database refuses unknown statuses and an incomplete Ready to sell" do
    departure = agencies(:harbor).departures.create!(name: "Checks")
    { sales_status: "published", operating_decision: "maybe", completion_status: "reconciled" }.each do |column, value|
      assert_raises(ActiveRecord::StatementInvalid, column.to_s) do
        Departure.transaction(requires_new: true) { Departure.where(id: departure.id).update_all(column => value) }
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Departure.transaction(requires_new: true) do
        Departure.where(id: departure.id).update_all(sales_status: "ready_to_sell", departure_reference: "DEP-8888", first_activated_at: Time.current)
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Departure.transaction(requires_new: true) { Departure.where(id: departure.id).update_all(departed_at: Time.current) }
    end
  end
end
