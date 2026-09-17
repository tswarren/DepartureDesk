require "test_helper"

class M3D0StructureRequestTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @staff = agency_users(:harbor_staff)
    @viewer = agency_users(:harbor_viewer)
    @office = offices(:harbor_main)
    ensure_supplier_sequence!
    @supplier = create_supplier("Structure Hotel").record
    @provider = create_supplier("Structure DMC").record
    @departure = create_departure
    @arrangement = CreateSupplierArrangement.new(
      agency: @agency,
      actor: @admin,
      departure: @departure,
      idempotency_key: SecureRandom.uuid,
      attributes: { name: "Structure workspace", contracting_supplier_id: @supplier.id }
    ).call.record
  end

  test "staff creates an item with its first occurrence and resource in one setup" do
    sign_in_as @staff

    get departure_arrangement_new_item_setup_path(@departure, @arrangement)
    assert_response :success
    assert_select "h1", text: "Set up item"
    assert_select "input[name=idempotency_key]", count: 1
    assert_select "[data-controller='optional-setup-sections']", count: 1

    version = @arrangement.versions.first
    assert_difference -> { @arrangement.arrangement_items.count }, 1 do
      assert_difference -> { ServiceOccurrence.where(supplier_arrangement: @arrangement).count }, 1 do
        assert_difference -> { SupplierResource.where(supplier_arrangement: @arrangement).count }, 1 do
          post departure_arrangement_item_setup_path(@departure, @arrangement), params: {
            idempotency_key: SecureRandom.uuid,
            version_lock_version: version.lock_version,
            include_occurrence: "1",
            include_resource: "1",
            arrangement_item_definition: {
              name: "Guest rooms",
              category: "lodging",
              default_service_provider_id: @provider.id,
              description: "Overnight accommodation"
            },
            service_occurrence_definition: {
              name: "Hotel stay",
              starts_on: "2026-10-01",
              ends_on: "2026-10-08",
              time_zone: "America/New_York"
            },
            supplier_resource_definition: {
              name: "Standard room",
              description: "Run of house"
            }
          }
        end
      end
    end

    item = @arrangement.arrangement_items.find_by!(
      id: @arrangement.versions.first.arrangement_item_definitions.find_by!(name: "Guest rooms").arrangement_item_id
    )
    assert_redirected_to departure_arrangement_path(@departure, @arrangement, anchor: "item-#{item.id}")
    assert_equal [ "Hotel stay" ],
      version.reload.service_occurrence_definitions.where(arrangement_item: item).pluck(:name)
    assert_equal [ "Standard room" ],
      version.supplier_resource_definitions.where(arrangement_item: item).pluck(:name)
  end

  test "setup validation preserves every selected section and creates nothing" do
    sign_in_as @staff
    key = SecureRandom.uuid
    version = @arrangement.versions.first

    assert_no_difference -> { @arrangement.arrangement_items.count } do
      post departure_arrangement_item_setup_path(@departure, @arrangement), params: {
        idempotency_key: key,
        version_lock_version: version.lock_version,
        include_occurrence: "1",
        include_resource: "1",
        arrangement_item_definition: {
          name: "Guest rooms",
          category: "lodging",
          description: "Keep this item description"
        },
        service_occurrence_definition: {
          name: "",
          starts_on: "2026-10-08",
          ends_on: "2026-10-01",
          time_zone: "America/New_York"
        },
        supplier_resource_definition: {
          name: "Standard room",
          description: "Keep this resource description"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "#form-error-summary[role=alert][tabindex='-1']"
    assert_select "input[name=idempotency_key][value=?]", key
    assert_select "input[name=include_occurrence][checked]", count: 1
    assert_select "input[name=include_resource][checked]", count: 1
    assert_select "input[name='arrangement_item_definition[name]'][value='Guest rooms']"
    assert_select "input[name='supplier_resource_definition[name]'][value='Standard room']"
    assert_select "a[href='#service_occurrence_definition_name']", count: 1
  end

  test "reading state hides movement controls and explicit reorder modes show them" do
    first_item = create_item("Rooms")
    second_item = create_item("Transfers")
    first_resource = create_resource(first_item, "Double room")
    second_resource = create_resource(first_item, "Single room")
    sign_in_as @staff

    get departure_arrangement_path(@departure, @arrangement)
    assert_response :success
    assert_select "a", text: "Reorder items", count: 1
    assert_select "a", text: "Reorder resources", minimum: 1
    assert_select "button", text: /Move (up|down)/, count: 0
    assert_match departure_arrangement_new_item_setup_path(@departure, @arrangement), response.body

    get departure_arrangement_path(@departure, @arrangement, structure_mode: "items")
    assert_select "button", text: "Move up", minimum: 1
    assert_select "button", text: "Move down", minimum: 1

    get departure_arrangement_path(
      @departure,
      @arrangement,
      structure_mode: "resources",
      structure_item_id: first_item.id
    )
    assert_select "button", text: "Move up", minimum: 1
    assert_select "button", text: "Move down", minimum: 1
    assert_select "a", text: "Done reordering", count: 1

    assert_equal [ first_resource.id, second_resource.id ],
      first_item.supplier_resources.order(:created_at).pluck(:id)
    assert_not_equal first_item.id, second_item.id
  end

  test "viewer cannot open or submit setup" do
    sign_in_as @viewer

    get departure_arrangement_new_item_setup_path(@departure, @arrangement)
    assert_redirected_to root_path

    post departure_arrangement_item_setup_path(@departure, @arrangement), params: {
      idempotency_key: SecureRandom.uuid,
      version_lock_version: @arrangement.versions.first.lock_version,
      arrangement_item_definition: { name: "Forbidden", category: "lodging" }
    }
    assert_redirected_to root_path
    assert_nil @arrangement.versions.first.arrangement_item_definitions.find_by(name: "Forbidden")
  end

  private

  def create_item(name)
    version = @arrangement.versions.first.reload
    CreateArrangementItem.new(
      agency: @agency,
      actor: @admin,
      arrangement: @arrangement,
      attributes: { name:, category: "lodging" },
      version_lock_version: version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
  end

  def create_resource(item, name)
    version = @arrangement.versions.first.reload
    CreateSupplierResource.new(
      agency: @agency,
      actor: @admin,
      item:,
      attributes: { name: },
      version_lock_version: version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
  end

  def create_supplier(display_name)
    CreateSupplier.new(
      agency: @agency,
      actor: @admin,
      kind: "organization",
      names: { display_name: },
      categories: [ "lodging" ]
    ).call
  end

  def create_departure
    CreateDeparture.new(
      agency: @agency,
      actor: @admin,
      attributes: {
        name: "M3D.0 Structure",
        starts_on: Date.new(2026, 10, 1),
        ends_on: Date.new(2026, 10, 8),
        time_zone: "America/New_York",
        operating_currency: "USD",
        responsible_office_id: @office.id,
        responsible_agency_user_id: @admin.id
      },
      current_office: @office
    ).call.record
  end

  def ensure_supplier_sequence!
    @agency.reference_sequences.find_or_create_by!(namespace: ReferenceSequence::SUPPLIER_NAMESPACE) do |sequence|
      sequence.next_value = 1
    end
  end
end
