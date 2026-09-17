require "test_helper"

class M3d1CommitmentTriggersRequestTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @staff = agency_users(:harbor_staff)
    @viewer = agency_users(:harbor_viewer)
    @agency.reference_sequences.find_or_create_by!(
      namespace: ReferenceSequence::SUPPLIER_NAMESPACE
    ) { |sequence| sequence.next_value = 1 }
    @supplier = CreateSupplier.new(
      agency: @agency, actor: @admin, kind: "organization",
      names: { display_name: "Request Trigger Supplier" }, categories: [ "lodging" ]
    ).call.record
    @departure = CreateDeparture.new(
      agency: @agency, actor: @admin, current_office: offices(:harbor_main),
      attributes: {
        name: "Trigger Request Departure", starts_on: Date.new(2027, 6, 1),
        ends_on: Date.new(2027, 6, 5), time_zone: "America/New_York",
        operating_currency: "USD", responsible_office_id: offices(:harbor_main).id,
        responsible_agency_user_id: @admin.id
      }
    ).call.record
    @arrangement = CreateSupplierArrangement.new(
      agency: @agency, actor: @admin, departure: @departure,
      idempotency_key: SecureRandom.uuid,
      attributes: { name: "Request Trigger Arrangement", contracting_supplier_id: @supplier.id }
    ).call.record
    @version = @arrangement.versions.first
  end

  test "staff creates updates and removes a draft trigger through exact version routes" do
    sign_in_as @staff
    get new_departure_arrangement_version_commitment_trigger_path(
      @departure, @arrangement, @version
    )
    assert_response :success
    assert_select "h1", text: "Add commitment trigger"

    assert_difference -> { SupplierCommitmentTriggerDefinition.count }, 1 do
      post departure_arrangement_version_commitment_triggers_path(
        @departure, @arrangement, @version
      ), params: {
        idempotency_key: SecureRandom.uuid,
        version_lock_version: @version.lock_version,
        supplier_commitment_trigger_definition: trigger_params
      }
    end
    trigger = @version.supplier_commitment_trigger_definitions.first
    assert_redirected_to departure_arrangement_version_commitment_triggers_path(
      @departure, @arrangement, @version
    )

    patch departure_arrangement_version_commitment_trigger_path(
      @departure, @arrangement, @version, trigger
    ), params: {
      supplier_commitment_trigger_definition: trigger_params.merge(
        description: "Updated request guarantee", lock_version: trigger.lock_version
      )
    }
    assert_equal "Updated request guarantee", trigger.reload.description

    delete departure_arrangement_version_commitment_trigger_path(
      @departure, @arrangement, @version, trigger
    ), params: { version_lock_version: @version.reload.lock_version }
    assert_not SupplierCommitmentTriggerDefinition.exists?(trigger.id)
  end

  test "viewer sees triggers without mutation controls" do
    sign_in_as @viewer
    get departure_arrangement_version_commitment_triggers_path(
      @departure, @arrangement, @version
    )
    assert_response :success
    assert_select "a", text: "Add commitment trigger", count: 0
  end

  private

  def trigger_params
    {
      trigger_kind: "arrangement_confirmation",
      authority_shape: "fixed_quantity",
      description: "Request guarantee",
      committed_supplier_id: @supplier.id,
      fixed_quantity: 3,
      quantity_basis: "resource_units"
    }
  end
end
