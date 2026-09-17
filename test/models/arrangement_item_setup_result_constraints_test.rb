require "test_helper"

class ArrangementItemSetupResultConstraintsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @other_agency = agencies(:cove)
    @departure = create_capacity_departure(@agency, name: "Setup result constraints")
    @contractor = create_capacity_supplier(@agency, "Setup result contractor")
    @provider = create_capacity_supplier(@agency, "Setup result provider")
    @graph = create_graph(@agency, @departure, @contractor, @provider, "Owned")
    @other_item_graph = create_graph(@agency, @departure, @contractor, @provider, "Other item")

    other_departure = create_capacity_departure(@other_agency, name: "Other setup result constraints")
    other_contractor = create_capacity_supplier(@other_agency, "Other setup result contractor")
    other_provider = create_capacity_supplier(@other_agency, "Other setup result provider")
    @other_agency_graph = create_graph(
      @other_agency, other_departure, other_contractor, other_provider, "Other agency"
    )
  end

  test "database rejects an occurrence owned by another item" do
    assert_foreign_key_rejected do
      insert_setup_result!(service_occurrence: @other_item_graph[:occurrence])
    end
  end

  test "database rejects a resource owned by another item" do
    key = insert_setup_result!

    assert_foreign_key_rejected do
      ArrangementItemSetupResult.where(agency_command_idempotency_key: key).update_all(
        supplier_resource_id: @other_item_graph[:resource].id
      )
    end
  end

  test "database rejects a cross-Agency occurrence" do
    assert_foreign_key_rejected do
      insert_setup_result!(service_occurrence: @other_agency_graph[:occurrence])
    end
  end

  test "database rejects a cross-Agency resource" do
    key = insert_setup_result!

    assert_foreign_key_rejected do
      ArrangementItemSetupResult.where(agency_command_idempotency_key: key).update_all(
        supplier_resource_id: @other_agency_graph[:resource].id
      )
    end
  end

  test "deleting a referenced occurrence is restricted" do
    insert_setup_result!(service_occurrence: @graph[:occurrence])

    assert_foreign_key_rejected { @graph[:occurrence].delete }
    assert ServiceOccurrence.exists?(@graph[:occurrence].id)
  end

  test "deleting a referenced resource is restricted" do
    insert_setup_result!(supplier_resource: @graph[:resource])

    assert_foreign_key_rejected { @graph[:resource].delete }
    assert SupplierResource.exists?(@graph[:resource].id)
  end

  private

  def create_graph(agency, departure, contractor, provider, prefix)
    create_capacity_graph(
      agency: agency,
      departure: departure,
      contractor: contractor,
      provider: provider,
      prefix: prefix
    )
  end

  def insert_setup_result!(service_occurrence: nil, supplier_resource: nil)
    key = @agency.agency_command_idempotency_keys.create!(
      command_name: "CreateArrangementItemSetup",
      idempotency_key: SecureRandom.uuid,
      payload_digest: "sha256:#{SecureRandom.hex(32)}",
      result_record_type: "ArrangementItem",
      result_record_id: @graph[:item].id
    )
    ArrangementItemSetupResult.insert!({
      agency_id: @agency.id,
      agency_command_idempotency_key_id: key.id,
      arrangement_item_id: @graph[:item].id,
      service_occurrence_id: service_occurrence&.id,
      supplier_resource_id: supplier_resource&.id,
      created_at: Time.current,
      updated_at: Time.current
    })
    key
  end

  def assert_foreign_key_rejected(&)
    assert_raises(ActiveRecord::InvalidForeignKey, ActiveRecord::StatementInvalid) do
      ArrangementItemSetupResult.transaction(requires_new: true, &)
    end
  end
end
