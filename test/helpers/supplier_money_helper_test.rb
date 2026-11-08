require "test_helper"

# The supplier payment sentence (SMN-04, SMN-10, SMN-11) for the Alpha fixture's payments.
class SupplierMoneyHelperTest < ActionView::TestCase
  setup do
    set_clock Time.utc(2026, 10, 15, 14)
    @alpha = AlphaFixture.load!(agency: agencies(:harbor), actor: agency_users(:harbor_admin))
  end

  test "Alpha's payments read as one sentence each" do
    sentences = @alpha.arrangements.values.flat_map(&:schedule_lines).to_h { |line| [ line.description, schedule_line_sentence(line) ] }
    deposit = sentences.fetch("Full deposit, $450 per cabin")
    assert_match(/\A\$450\.00 for each cabin, due when a client booking for that cabin is confirmed, or on [A-Z][a-z]{2} \d{1,2}, \d{4} for any cabin still unbooked\.\z/, deposit)
    assert_match(/\A\$50\.00 for each one in the count, /, sentences.fetch("Initial deposit, $50 per stateroom"))
    sentences.each_value { |sentence| assert_match(/\A.+, due .+\.\z/, sentence) }
  end

  test "the unit noun follows the service category" do
    cruise = @alpha.arrangements.fetch(:cruise)
    hotel = @alpha.arrangements.fetch(:hotel)
    assert_equal "cabin", payment_unit_noun(cruise)
    assert_equal "room", payment_unit_noun(hotel)
    assert_equal "room", payment_unit_noun(hotel, hotel.inventory_groups.first)
  end
end
