require "test_helper"

class M3ASupplierArrangementsRequestTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @staff = agency_users(:harbor_staff)
    @viewer = agency_users(:harbor_viewer)
    @office = offices(:harbor_main)
    ensure_supplier_sequence!(@agency)
    @supplier = create_supplier(@agency, @admin, "Harbor Hotel").record
    @provider = create_supplier(@agency, @admin, "Harbor DMC").record
    @contact = @supplier.contacts.create!(
      agency: @agency,
      first_name: "Casey",
      last_name: "Planner",
      status: "active"
    )
    @departure = create_complete_draft(@agency, @admin, "M3A Request Draft")
  end

  test "admin creates arrangement shell and child planning records" do
    sign_in_as @admin

    get new_departure_arrangement_path(@departure)
    assert_response :success
    assert_select "input[name=idempotency_key]", count: 1

    assert_difference -> { @departure.supplier_arrangements.count }, 1 do
      post departure_arrangements_path(@departure), params: {
        idempotency_key: SecureRandom.uuid,
        supplier_arrangement: {
          name: "Hotel Block",
          contracting_supplier_id: @supplier.id,
          supplier_contact_id: @contact.id
        }
      }
    end
    arrangement = @departure.supplier_arrangements.find_by!(name: "Hotel Block")
    assert_redirected_to departure_arrangement_path(@departure, arrangement)

    get departure_arrangement_path(@departure, arrangement)
    assert_response :success
    assert_match "Hotel Block", response.body

    version = arrangement.versions.first
    assert_difference -> { arrangement.arrangement_items.count }, 1 do
      post departure_arrangement_items_path(@departure, arrangement), params: {
        idempotency_key: SecureRandom.uuid,
        version_lock_version: version.lock_version,
        arrangement_item_definition: {
          name: "Rooms",
          category: "lodging",
          default_service_provider_id: @provider.id
        }
      }
    end
    item = arrangement.arrangement_items.first
    assert_redirected_to departure_arrangement_path(@departure, arrangement, anchor: "item-#{item.id}")

    assert_difference -> { item.service_occurrences.count }, 1 do
      post departure_arrangement_item_occurrences_path(@departure, arrangement, item), params: {
        idempotency_key: SecureRandom.uuid,
        version_lock_version: version.reload.lock_version,
        service_occurrence_definition: {
          name: "Check in",
          starts_on: "2026-10-01",
          ends_on: "2026-10-01",
          time_zone: "America/New_York"
        }
      }
    end

    assert_difference -> { item.supplier_resources.count }, 1 do
      post departure_arrangement_item_resources_path(@departure, arrangement, item), params: {
        idempotency_key: SecureRandom.uuid,
        version_lock_version: version.reload.lock_version,
        supplier_resource_definition: { name: "Room block" }
      }
    end
  end

  test "invalid create preserves submitted values and idempotency key" do
    sign_in_as @admin
    key = SecureRandom.uuid

    post departure_arrangements_path(@departure), params: {
      idempotency_key: key,
      supplier_arrangement: {
        name: "",
        contracting_supplier_id: @supplier.id,
        supplier_contact_id: @contact.id
      }
    }

    assert_response :unprocessable_entity
    assert_select "#form-error-summary"
    assert_select "input[name=idempotency_key][value=?]", key
    assert_select "select[name='supplier_arrangement[contracting_supplier_id]'] option[selected][value=?]", @supplier.id
  end

  test "viewer can read supplier planning but cannot mutate" do
    arrangement = create_arrangement("Viewer Visible")
    sign_in_as @viewer

    get departure_arrangement_path(@departure, arrangement)
    assert_response :success
    assert_match "Viewer Visible", response.body
    assert_select "a", text: "Edit arrangement", count: 0

    get new_departure_arrangement_path(@departure)
    assert_redirected_to root_path
    post departure_arrangements_path(@departure), params: {
      idempotency_key: SecureRandom.uuid,
      supplier_arrangement: { name: "Viewer Write", contracting_supplier_id: @supplier.id }
    }
    assert_redirected_to root_path
    assert_nil @departure.supplier_arrangements.find_by(name: "Viewer Write")
  end

  test "cross agency arrangement routes are not found" do
    other_agency = agencies(:cove)
    other_admin = agency_users(:cove_admin)
    ensure_supplier_sequence!(other_agency)
    other_supplier = create_supplier(other_agency, other_admin, "Cove Hotel").record
    other_departure = create_complete_draft(other_agency, other_admin, "Cove M3A")
    other_arrangement = CreateSupplierArrangement.new(
      agency: other_agency,
      actor: other_admin,
      departure: other_departure,
      idempotency_key: SecureRandom.uuid,
      attributes: { name: "Foreign Arrangement", contracting_supplier_id: other_supplier.id }
    ).call.record

    sign_in_as @admin

    get departure_arrangement_path(other_departure, other_arrangement)
    assert_response :not_found
    patch departure_arrangement_path(other_departure, other_arrangement), params: {
      supplier_arrangement: { name: "Stolen", supplier_contact_id: "", lock_version: other_arrangement.lock_version }
    }
    assert_response :not_found
    assert_equal "Foreign Arrangement", other_arrangement.reload.name
  end

  test "staff abandons tentative arrangement through confirmation" do
    arrangement = create_arrangement("To Abandon")
    version = arrangement.versions.first
    sign_in_as @staff

    get abandon_departure_arrangement_path(@departure, arrangement)
    assert_response :success
    assert_match "Abandon arrangement", response.body

    post abandon_departure_arrangement_path(@departure, arrangement), params: {
      reason: "Supplier withdrew tentative space",
      arrangement_lock_version: arrangement.lock_version,
      version_lock_version: version.lock_version
    }

    assert_redirected_to departure_arrangement_path(@departure, arrangement)
    assert_equal "abandoned", arrangement.reload.status
    assert_equal "Supplier withdrew tentative space", version.reload.abandoned_reason
  end

  private

  def create_arrangement(name)
    CreateSupplierArrangement.new(
      agency: @agency,
      actor: @admin,
      departure: @departure,
      idempotency_key: SecureRandom.uuid,
      attributes: { name:, contracting_supplier_id: @supplier.id, supplier_contact_id: @contact.id }
    ).call.record
  end

  def create_supplier(agency, actor, display_name)
    CreateSupplier.new(
      agency:,
      actor:,
      kind: "organization",
      names: { display_name: },
      categories: [ "lodging" ]
    ).call
  end

  def create_complete_draft(agency, actor, name)
    CreateDeparture.new(
      agency:,
      actor:,
      attributes: {
        name:,
        starts_on: Date.new(2026, 10, 1),
        ends_on: Date.new(2026, 10, 8),
        time_zone: "America/New_York",
        operating_currency: "USD",
        responsible_office_id: agency.offices.first.id,
        responsible_agency_user_id: actor.id
      },
      current_office: agency.offices.first
    ).call.record
  end

  def ensure_supplier_sequence!(agency)
    agency.reference_sequences.find_or_create_by!(namespace: ReferenceSequence::SUPPLIER_NAMESPACE) do |sequence|
      sequence.next_value = 1
    end
  end
end
