require "test_helper"

# S-12 to S-16 (UX consolidation audit batch 4): the arrangement's sub-pages
# (B1, decision 3), each shown only to staff who may see it; the capacity,
# capacity rule and document forms re-render on refusal (C1); the cost line
# and trigger event forms show only the fields a choice uses (C3).
class ArrangementPagesTest < ActionDispatch::IntegrationTest
  setup do
    set_clock Time.utc(2027, 1, 12, 15)
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @alpha = AlphaFixture.load!(agency: @agency, actor: @admin, bookings: :confirmed)
    @departure = @alpha.departure
    @hotel = @alpha.arrangements.fetch(:hotel)
  end

  test "the arrangement opens on its overview and each part has its own page" do
    sign_in_as @admin
    get departure_arrangement_path(@departure, @hotel)
    assert_response :success
    assert_select "nav[aria-label='Arrangement sections'] a", count: 6
    assert_select "nav[aria-label='Arrangement sections'] a[aria-current=page]", text: "Overview"
    assert_select "#arrangement-details"
    assert_select "#inventory, #supplier-cost, #supplier-payments, #deadlines, #supplier-reservations, #documents", count: 0

    {
      departure_arrangement_inventory_path(@departure, @hotel) => [ "Inventory", %w[#inventory] ],
      departure_arrangement_costs_path(@departure, @hotel) => [ "Rates and cost", %w[#rate-table #supplier-cost] ],
      departure_arrangement_payments_path(@departure, @hotel) => [ "Payments and deadlines", %w[#supplier-payments #deadlines] ],
      departure_arrangement_reservations_path(@departure, @hotel) => [ "Reservations", %w[#supplier-reservations] ],
      departure_arrangement_documents_path(@departure, @hotel) => [ "Documents", %w[#documents] ]
    }.each do |path, (tab, panels)|
      get path
      assert_response :success
      assert_select "nav[aria-label='Arrangement sections'] a[aria-current=page]", text: tab
      assert_select "nav[aria-label=Breadcrumb] a", text: @hotel.arrangement_reference
      panels.each { |panel| assert_select panel }
    end
  end

  test "baseline staff see the overview, inventory and deadlines, but no supplier cost pages (ACC-31)" do
    sign_in_as agency_users(:harbor_baseline_staff)
    get departure_arrangement_path(@departure, @hotel)
    assert_select "nav[aria-label='Arrangement sections'] a", text: "Rates and cost", count: 0
    assert_select "nav[aria-label='Arrangement sections'] a", text: "Documents", count: 0
    assert_select "nav[aria-label='Arrangement sections'] a", text: "Deadlines"
    get departure_arrangement_inventory_path(@departure, @hotel)
    assert_response :success
    get departure_arrangement_costs_path(@departure, @hotel)
    assert_redirected_to root_path
  end

  test "a draft arrangement's Reservations page says when they start" do
    draft = draft_arrangement!
    sign_in_as @admin
    get departure_arrangement_reservations_path(@departure, draft)
    assert_select "#supplier-reservations", text: /start once the arrangement is confirmed/
  end

  test "another agency's arrangement pages are not found" do
    sign_in_as agency_users(:cove_admin)
    get departure_arrangement_payments_path(@departure, @hotel)
    assert_response :not_found
  end

  test "a refused capacity change keeps what was typed and marks the field (C1)" do
    group = @hotel.inventory_groups.find_by!(label: "Nov 4 Garden Queen")
    sign_in_as @admin
    events = group.capacity_events.count
    post departure_arrangement_group_capacity_events_path(@departure, @hotel, group), params: {
      kind: "supplier_release", quantity: "50", effective_on: "2027-01-20", evidence_note: "Hotel email", idempotency_key: "r-1"
    }
    assert_response :unprocessable_entity
    assert_equal events, group.capacity_events.count
    assert_select "#supply-change #form-error-summary a[href='#supplier_release_quantity']"
    assert_select "#supplier_release_quantity[value='50'][aria-invalid=true]"
    assert_select "#supplier_release_quantity_error"
    assert_select "#kind_supplier_release[checked]"
    assert_select "#evidence_note", text: "Hotel email"
    assert_select "#supply-change aside", text: /In plain words/
  end

  test "a refused capacity rule re-renders the group with the message" do
    draft = draft_arrangement!
    group = SaveInventoryGroup.new(agency: @agency, actor: @admin, departure: @departure, arrangement: draft,
      attributes: { label: "Coach seats", service_category: "transportation", representation: "capacity_pool", quantity: "40", starts_on: "2027-11-06", ends_on: "2027-11-06" }).call.record
    sign_in_as @admin
    patch departure_arrangement_group_capacity_rule_path(@departure, draft, group), params: { traveler_type_id: "", uses_capacity: "false" }
    assert_response :unprocessable_entity
    assert_select "#capacity-rules #form-error-summary", text: /Choose a traveler type/
  end

  test "the cost line form shows each field for the scope and basis that use it, with a sentence (C2, C3)" do
    sign_in_as @admin
    get new_departure_arrangement_cost_line_path(@departure, @hotel)
    assert_select "[data-show-for=inventory_group] select[name='cost_line[inventory_group_id]']"
    assert_select "[data-show-for=unit_shells] legend", text: "Shells it covers"
    assert_select "[data-show-for=percentage] input[name='cost_line[percentage]']"
    assert_select "[data-show-for='per_unit per_person per_night'] input[name='cost_line[quantity]']"
    assert_select "aside", text: /In plain words/
  end

  test "the event form asks for a count only for an event a count-based payment waits on" do
    sign_in_as @admin
    get new_departure_arrangement_trigger_event_path(@departure, @hotel)
    assert_select "input[name='trigger_event[count]']", count: 0

    SaveScheduleLine.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @hotel, attributes: {
      "description" => "Names fee", "amount_kind" => "per_unit_count", "rate" => "5", "due_rule" => "event", "trigger_type" => "rooming_list_submitted"
    }).call
    get new_departure_arrangement_trigger_event_path(@departure, @hotel)
    assert_select "[data-show-for=rooming_list_submitted] input[name='trigger_event[count]']"
    assert_select "#trigger_event_count_hint", text: /Names fee uses it/
  end

  private

  def draft_arrangement!
    supplier = CreateSupplier.new(agency: @agency, actor: @admin, kind: "organization", names: { display_name: "Draft Coaches" }, categories: [ "cruise_line" ]).call.record
    CreateSupplierArrangement.new(agency: @agency, actor: @admin, departure: @departure, supplier_id: supplier.id).call.record
  end
end
