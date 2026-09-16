require "test_helper"

class ChangeSupplierStatusM3aTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @staff = agency_users(:harbor_staff)
    @office = offices(:harbor_main)
    ensure_supplier_sequence!(@agency)
    @contractor = create_supplier("Contractor").record
    @provider = create_supplier("Default Provider").record
    @unused_provider = create_supplier("Unused Provider").record
    @departure = create_complete_draft("M3A Supplier Status")
  end

  test "ordinary inactivation is blocked by draft arrangement contractor dependency" do
    arrangement = create_arrangement(@contractor)

    error = assert_raises(AgencyCommand::Error) do
      ChangeSupplierStatus.new(
        agency: @agency,
        actor: @admin,
        supplier: @contractor,
        status: "inactive",
        lock_version: @contractor.lock_version
      ).call
    end

    assert_equal :dependency_exists, error.code
    assert_equal "active", @contractor.reload.status
    assert_equal "draft", arrangement.reload.status
  end

  test "effective provider fallback blocks current planned occurrence but unused default and past windows do not" do
    arrangement = create_arrangement(@contractor)
    item = create_item(arrangement, default_provider: @provider)
    create_occurrence(item, idempotency_key: "future-occ", starts_on: "2026-10-01", ends_on: "2026-10-02")

    blocked = assert_raises(AgencyCommand::Error) do
      ChangeSupplierStatus.new(
        agency: @agency,
        actor: @admin,
        supplier: @provider,
        status: "inactive",
        lock_version: @provider.lock_version
      ).call
    end
    assert_equal :dependency_exists, blocked.code

    unused_arrangement = create_arrangement(create_supplier("Unused Contractor").record, idempotency_key: "unused-arr")
    create_item(unused_arrangement, default_provider: @unused_provider, idempotency_key: "unused-item")
    result = ChangeSupplierStatus.new(
      agency: @agency,
      actor: @admin,
      supplier: @unused_provider,
      status: "inactive",
      lock_version: @unused_provider.lock_version
    ).call
    assert_equal :updated, result.status

    past_provider = create_supplier("Past Provider").record
    past_arrangement = create_arrangement(create_supplier("Past Contractor").record, idempotency_key: "past-arr")
    past_item = create_item(past_arrangement, default_provider: past_provider, idempotency_key: "past-item")
    create_occurrence(past_item, idempotency_key: "past-occ", starts_on: "2026-01-01", ends_on: "2026-01-02")
    past_result = ChangeSupplierStatus.new(
      agency: @agency,
      actor: @admin,
      supplier: past_provider,
      status: "inactive",
      lock_version: past_provider.lock_version
    ).call
    assert_equal :updated, past_result.status
  end

  test "abandoned arrangements do not block supplier inactivation" do
    supplier = create_supplier("Abandoned Contractor").record
    arrangement = create_arrangement(supplier, idempotency_key: "abandoned-arr")
    version = arrangement.versions.first
    AbandonSupplierArrangement.new(
      agency: @agency,
      actor: @admin,
      arrangement: arrangement,
      reason: "Not needed",
      arrangement_lock_version: arrangement.lock_version,
      version_lock_version: version.lock_version
    ).call

    result = ChangeSupplierStatus.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier.reload,
      status: "inactive",
      lock_version: supplier.lock_version
    ).call
    assert_equal :updated, result.status
  end

  test "force inactivation requires administrator force permission and records affected arrangements" do
    arrangement = create_arrangement(@contractor)

    unauthorized = assert_raises(AgencyCommand::Error) do
      ChangeSupplierStatus.new(
        agency: @agency,
        actor: @staff,
        supplier: @contractor,
        status: "inactive",
        lock_version: @contractor.lock_version,
        force: true,
        force_reason: "Proceed despite tentative planning"
      ).call
    end
    assert_equal :unauthorized, unauthorized.code

    result = ChangeSupplierStatus.new(
      agency: @agency,
      actor: @admin,
      supplier: @contractor.reload,
      status: "inactive",
      lock_version: @contractor.lock_version,
      force: true,
      force_reason: "Proceed despite tentative planning"
    ).call
    assert_equal :updated, result.status
    audit = AuditEvent.where(action: "supplier.inactivated", subject_id: @contractor.id).last
    assert_equal true, audit.details["forced"]
    assert_equal "Proceed despite tentative planning", audit.details["force_reason"]
    assert_equal [ arrangement.id ], audit.details["affected_supplier_arrangement_ids"]
  end

  private

  def create_arrangement(contractor, idempotency_key: SecureRandom.hex(6))
    CreateSupplierArrangement.new(
      agency: @agency,
      actor: @admin,
      departure: @departure,
      idempotency_key: idempotency_key,
      attributes: { name: "Supplier Plan #{SecureRandom.hex(3)}", contracting_supplier_id: contractor.id }
    ).call.record
  end

  def create_item(arrangement, default_provider:, idempotency_key: SecureRandom.hex(6))
    version = arrangement.versions.first.reload
    CreateArrangementItem.new(
      agency: @agency,
      actor: @admin,
      arrangement: arrangement,
      version_lock_version: version.lock_version,
      idempotency_key: idempotency_key,
      attributes: {
        name: "Lodging",
        category: "lodging",
        default_service_provider_id: default_provider.id
      }
    ).call.record
  end

  def create_occurrence(item, idempotency_key:, starts_on:, ends_on:)
    version = item.supplier_arrangement.versions.first.reload
    CreateServiceOccurrence.new(
      agency: @agency,
      actor: @admin,
      item: item,
      version_lock_version: version.lock_version,
      idempotency_key: idempotency_key,
      attributes: { name: "Stay", starts_on: starts_on, ends_on: ends_on }
    ).call.record
  end

  def create_supplier(display_name)
    CreateSupplier.new(
      agency: @agency,
      actor: @admin,
      kind: "organization",
      names: { display_name: display_name },
      categories: [ "lodging" ]
    ).call
  end

  def create_complete_draft(name)
    CreateDeparture.new(
      agency: @agency,
      actor: @admin,
      attributes: {
        name: name,
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

  def ensure_supplier_sequence!(agency)
    agency.reference_sequences.find_or_create_by!(namespace: ReferenceSequence::SUPPLIER_NAMESPACE) do |sequence|
      sequence.next_value = 1
    end
  end
end
