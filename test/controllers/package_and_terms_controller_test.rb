require "test_helper"

# S-20, S-21 and the Administration client terms page: BKG-13 to BKG-16,
# BKG-21, BKG-28, BKG-31, CMN-09, ACC-30.
class PackageAndTermsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @alpha = AlphaFixture.load!(agency: @agency, actor: @admin)
    @departure = @alpha.departure
    @offering = @alpha.offering
  end

  test "baseline staff see the package's choices and client prices, without edit actions (ACC-30)" do
    sign_in_as agency_users(:harbor_baseline_staff)
    get departure_offerings_path(@departure)
    assert_select "nav[aria-label='Departure sections'] a[aria-current=page]", text: "Package"
    assert_select "h3", text: "Cabin"
    assert_select "p", text: "Included · Per unit · Required, choose one"
    assert_select "td", text: /1st guest \$3,385\.00/
    assert_select "td", text: /Any position, Child 0–4 \$0\.00/
    assert_select "a", text: "Edit prices", count: 0
    get new_departure_offering_choice_path(@departure, @offering)
    assert_redirected_to root_path
  end

  test "Departure management adds a choice and an option, then sets and removes a price" do
    sign_in_as agency_users(:harbor_staff)
    post departure_offering_choices_path(@departure, @offering), params: { offering_choice: { name: "Transfer", role: "add_on", scope: "per_traveler", pattern: "optional_single" } }
    choice = @offering.choices.find_by!(name: "Transfer")
    group = @alpha.arrangements.fetch(:excursion).inventory_groups.sole
    post departure_offering_choice_options_path(@departure, @offering, choice), params: { offering_option: { label: "Port transfer", inventory_group_id: group.id } }
    option = choice.options.sole
    assert_redirected_to edit_departure_offering_choice_option_path(@departure, @offering, choice, option)

    get edit_departure_offering_choice_option_path(@departure, @offering, choice, option)
    assert_select "p", text: /Still needed: any position/
    post departure_offering_prices_path(@departure, @offering), params: { offering_price: { offering_option_id: option.id, occupancy_position: "any", amount: "45" } }
    assert_equal [ 4_500 ], option.prices.pluck(:amount_minor_units)

    post departure_offering_prices_path(@departure, @offering), params: { offering_price: { offering_option_id: option.id, occupancy_position: "any", amount: "4.555" } }
    follow_redirect!
    assert_select ".dd-alert--danger", text: /must be an amount in USD/

    delete departure_offering_price_path(@departure, @offering, option.prices.sole)
    assert_empty option.prices.reload
  end

  test "an invalid choice re-renders with its error" do
    sign_in_as @admin
    post departure_offering_choices_path(@departure, @offering), params: { offering_choice: { name: "Cabin again", role: "included", scope: "per_unit", pattern: "optional_multiple" } }
    assert_response :unprocessable_entity
    assert_select "#form-error-summary", text: /only to add-ons/
  end

  test "the client terms tab shows the wording, the override tiers and the payment schedule" do
    sign_in_as agency_users(:harbor_baseline_staff)
    get departure_client_terms_path(@departure)
    assert_select "nav[aria-label='Departure sections'] a[aria-current=page]", text: "Client terms"
    assert_select "#wording h2", text: "Version 1"
    assert_select "#cancellation li", text: "120 days or more before departure: 10% of the service's charge"
    assert_select "#cancellation li", text: "Up to departure: 100% of the service's charge"
    assert_select "#payment-schedule th", text: "Deposit"
    assert_select "#payment-schedule td", text: /\$500\.00 per cruise unit/
    assert_select "#payment-schedule td", text: /120 days before departure/
    assert_select "#payment-schedule a", text: "Edit", count: 0
  end

  test "staff edit the payment schedule and override tiers; returning to the agency tiers discards the override" do
    terms = @alpha.client_terms
    sign_in_as @admin
    post departure_client_schedule_lines_path(@departure), params: { client_payment_schedule_line: {
      description: "Second deposit", basis: "per_traveler", amount: "250", due_rule: "fixed_date", due_on: "2027-03-01", counts_as_acceptance: "0"
    } }
    assert_redirected_to departure_client_terms_path(@departure, anchor: "payment-schedule")
    assert_equal 25_000, terms.schedule_lines.reload.find_by!(description: "Second deposit").amount_minor_units

    post departure_client_schedule_lines_path(@departure), params: { client_payment_schedule_line: { description: "Bad", basis: "per_unit", amount: "1", due_rule: "at_confirmation" } }
    assert_response :unprocessable_entity
    assert_select "#form-error-summary", text: /service category/i

    patch departure_client_terms_path(@departure), params: { client_terms_version: { overrides_cancellation_tiers: "false", lock_version: terms.reload.lock_version } }
    assert_not terms.reload.overrides_cancellation_tiers?
    assert_empty terms.own_cancellation_tiers
  end

  test "terms start from the agency's or copy another Departure's" do
    other = CreateDeparture.new(agency: @agency, actor: @admin, attributes: { name: "Second sailing", operating_currency: "USD" }).call.record
    sign_in_as @admin
    get departure_client_terms_path(other)
    assert_select "button", text: "Start from agency terms"
    post departure_client_terms_path(other), params: { source_departure_id: @departure.id }
    copy = other.reload.current_client_terms
    assert_equal [ @departure, 2 ], [ copy.copied_from_departure, copy.schedule_lines.size ]
  end

  test "agency defaults are Agency Admin only" do
    sign_in_as @admin
    get administration_client_terms_defaults_path
    assert_select "nav[aria-label='Administration'] a[aria-current=page]", text: "Client terms"
    post administration_cancellation_tiers_path, params: { cancellation_tier: { min_days_before_departure: "30", charge_kind: "fixed_per_unit", amount: "250", service_category: "cruise" } }
    assert_redirected_to administration_client_terms_defaults_path(anchor: "cancellation")
    assert_equal [ 25_000, "cruise" ], @agency.agency_cancellation_tiers.find_by!(min_days_before_departure: 30).values_at(:amount_minor_units, :service_category)

    sign_in_as agency_users(:harbor_staff)
    get administration_client_terms_defaults_path
    assert_redirected_to root_path
  end

  test "other agencies get not found" do
    sign_in_as agency_users(:cove_admin)
    get departure_offerings_path(@departure)
    assert_response :not_found
    get departure_client_terms_path(@departure)
    assert_response :not_found
  end
end
