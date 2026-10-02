# frozen_string_literal: true

require "test_helper"

class HotelReviewAndActivationTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @contractor = create_capacity_supplier(@agency, "Hilton Fort Lauderdale Marina")
    @departure = create_capacity_departure(@agency, name: "Smith Family Reunion")
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900000) + 100000}",
      first_activated_at: Time.current,
      time_zone: "America/New_York"
    )
    @graph = create_capacity_graph(
      agency: @agency, departure: @departure, contractor: @contractor,
      provider: @contractor, prefix: "Hilton", category: "lodging"
    )
    @arrangement = @graph[:arrangement]
    @version = @graph[:version]
    @item = @graph[:item]
    @other = add_activity_item
  end

  test "lodging readiness requires supplier confirmation and leaves other categories alone" do
    lodging = SupplierArrangementActivationReadiness.new(
      agency: @agency, arrangement: @arrangement, version: @version
    ).call
    assert_includes lodging.blockers.map(&:code), :lodging_agreement_unconfirmed

    confirm_directly!
    ready = SupplierArrangementActivationReadiness.new(
      agency: @agency, arrangement: @arrangement, version: @version.reload
    ).call
    assert_not_includes ready.blockers.map(&:code), :lodging_agreement_unconfirmed

    activity = create_capacity_graph(
      agency: @agency, departure: @departure, contractor: @contractor,
      provider: @contractor, prefix: "Transfer"
    )
    activity[:item_definition].update!(category: "ground_transportation")
    transfer = SupplierArrangementActivationReadiness.new(
      agency: @agency, arrangement: activity[:arrangement], version: activity[:version]
    ).call
    assert_not_includes transfer.blockers.map(&:code), :lodging_agreement_unconfirmed
    assert_not_includes transfer.blockers.map(&:code), :cruise_agreement_unconfirmed
  end

  test "confirmation freezes lodging facts and leaves an unrelated item editable" do
    confirm_directly!
    frozen = assert_raises(ActiveRecord::RecordInvalid) do
      @graph[:occurrence_definition].update!(name: "Changed stay")
    end
    assert_match(/immutable after Supplier confirmation/, frozen.message)
    assert_equal "Hilton occurrence", @graph[:occurrence_definition].reload.name

    @other[:occurrence_definition].update!(name: "Changed transfer")
    assert_equal "Changed transfer", @other[:occurrence_definition].reload.name
  end

  test "database freeze covers lodging parents and non-item coverage links" do
    deadline = CreateSupplierDeadlineDefinition.new(
      agency: @agency,
      actor: @admin,
      version: @version.reload,
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        deadline_type: "rooming_list_due",
        kind: "actionable",
        rule_shape: "fixed_local_datetime",
        rule_parameters: { "datetime" => "2027-10-03T17:00:00" },
        precision: "local_date_time",
        time_zone: "America/New_York",
        cardinality: "one_shared",
        coverage_links: [ { service_occurrence_id: @graph[:occurrence].id } ],
        commitment_lines: []
      }
    ).call.record

    ConfigureCapacityPairWithPool.new(
      agency: @agency,
      actor: @admin,
      item: @item,
      service_occurrence: @graph[:occurrence],
      supplier_resource: @graph[:resource],
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      pool_attributes: {
        label: "Hotel rooms",
        inventory_mode: "block",
        measurement_basis: "resource_units",
        unit_label: "rooms",
        proposed_opening_quantity: 2,
        evidence_kind: "contract",
        evidence_on: "2026-09-30",
        evidence_reference_note: "Hotel contract"
      }
    ).call
    pool = @version.reload.capacity_pool_definitions.find_by!(
      service_occurrence_id: @graph[:occurrence].id,
      supplier_resource_id: @graph[:resource].id
    ).capacity_pool

    deposit = CreateSupplierDepositRequirementDefinition.new(
      agency: @agency,
      actor: @admin,
      version: @version.reload,
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        amount_shape: "fixed_amount",
        fixed_amount_minor_units: 10_000,
        currency: "USD",
        rule_shape: "fixed_date",
        rule_parameters: { "date" => "2027-05-07" },
        precision: "date_only",
        time_zone: "America/New_York",
        coverage_links: [ { capacity_pool_id: pool.id } ],
        cost_links: [],
        contributor_definition_ids: []
      }
    ).call.record

    deadline_link = deadline.supplier_deadline_definition_coverage_links.sole
    deposit_link = deposit.supplier_deposit_requirement_definition_coverage_links.sole
    assert_equal pool.id, deposit_link.capacity_pool_id
    assert_nil deposit_link.arrangement_item_id
    assert_nil deposit_link.service_occurrence_id
    assert_nil deposit_link.supplier_resource_id
    confirm_directly!

    [
      [ "supplier_deadline_definitions", deadline.id ],
      [ "supplier_deadline_definition_coverage_links", deadline_link.id ],
      [ "supplier_deposit_requirement_definitions", deposit.id ],
      [ "supplier_deposit_requirement_definition_coverage_links", deposit_link.id ]
    ].each do |table, id|
      error = assert_raises(ActiveRecord::StatementInvalid) do
        ActiveRecord::Base.transaction(requires_new: true) do
          ActiveRecord::Base.connection.execute(
            "UPDATE #{table} SET updated_at = NOW() WHERE id = #{ActiveRecord::Base.connection.quote(id)}"
          )
        end
      end
      assert_match(/lodging agreement definitions are immutable after Supplier confirmation/, error.message)
    end
  end

  test "generic activation blockers keep specific Hotel-facing messages" do
    confirm_directly!

    review = CompileHotelActivationReview.new(
      agency: @agency,
      departure: @departure,
      arrangement: @arrangement,
      version: @version,
      item: @item
    ).call

    messages = review.blockers.map(&:message)
    assert_includes messages, "A retained service still needs Supplier cost coverage before activation."
    assert messages.none? { |message| message == "Operational Supplier setup needs attention before activation." }
  end

  test "revision abandons the confirmed draft and copies absences onto an unconfirmed draft" do
    absence = RecordSupplierAgreementReferenceAbsence.new(
      agency: @agency, actor: @admin, arrangement_item: @item, scope: "stay",
      kind: "cancellation", idempotency_key: SecureRandom.uuid
    ).call.record
    confirm_directly!

    revised = ReviseConfirmedHotelAgreement.new(
      agency: @agency, actor: @admin, arrangement: @arrangement,
      reason: "Rate changed before activation.",
      idempotency_key: SecureRandom.uuid,
      arrangement_lock_version: @arrangement.lock_version,
      version_lock_version: @version.lock_version
    ).call.record

    assert_equal "abandoned", @version.reload.status
    assert SupplierConfirmation.exists?(supplier_arrangement_version_id: @version.id)
    assert_equal "draft", @arrangement.reload.status
    assert_nil @arrangement.governing_version_id
    assert_equal @version.id, revised.copied_from_id
    assert_not SupplierConfirmation.exists?(supplier_arrangement_version_id: revised.id)
    copied = revised.supplier_agreement_reference_absences.find_by!(kind: "cancellation")
    assert_equal absence.id, copied.copied_from_id
    assert_equal @item.id, copied.arrangement_item_id

    abandoned = assert_raises(AgencyCommand::Error) do
      ActivateSupplierArrangementVersion.new(
        agency: @agency, actor: @admin, arrangement: @arrangement, version: @version,
        idempotency_key: SecureRandom.uuid,
        arrangement_lock_version: @arrangement.lock_version,
        version_lock_version: @version.lock_version,
        existing_confirmation_id: @version.supplier_confirmations.sole.id,
        cost_source_coverage_acknowledged: true,
        commitment_trigger_coverage_acknowledged: true
      ).call
    end
    assert_equal :invalid_state, abandoned.code

    readiness = SupplierArrangementActivationReadiness.new(
      agency: @agency, arrangement: @arrangement, version: revised
    ).call
    assert_not_includes readiness.blockers.map(&:code), :predecessor_not_governing
    assert_includes readiness.blockers.map(&:code), :lodging_agreement_unconfirmed
  end

  test "a missing rooming list is not reviewed none and does not block by itself" do
    review = CompileHotelActivationReview.new(
      agency: @agency, departure: @departure, arrangement: @arrangement,
      version: @version, item: @item
    ).call
    deadline = review.sections.find { |section| section.key == "deadlines" }
    assert_equal "No rooming list recorded", deadline.detail
    assert_not_equal "Reviewed — none", deadline.state
    assert review.blockers.none? { |blocker| blocker.message.match?(/rooming list/i) }
  end

  test "hotel confirmation stays closed until the hotel post would otherwise pass" do
    error = assert_raises(AgencyCommand::Error) do
      RecordHotelSupplierConfirmation.new(
        agency: @agency, actor: @admin, arrangement: @arrangement, version: @version,
        arrangement_item: @item, idempotency_key: SecureRandom.uuid,
        evidence_attributes: {
          evidence_kind: "supplier_confirmation", evidence_on: "2026-09-28",
          channel: "email", reference_note: "Hilton confirmed the stay.",
          confirmed_without_identifier_reason: "No hotel number was issued."
        }
      ).call
    end
    assert_equal :invalid, error.code
    assert_equal 0, SupplierConfirmation.where(supplier_arrangement_version_id: @version.id).count
  end

  private

  def confirm_directly!
    SupplierConfirmation.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version, confirming_supplier: @contractor,
      actor: @admin, evidence_kind: "supplier_confirmation", evidence_on: Date.new(2026, 9, 28),
      channel: "email", reference_note: "Confirmed the Hotel terms.",
      confirmed_without_identifier_reason: "No hotel number was issued.", recorded_at: Time.current
    )
  end

  def add_activity_item
    item = @arrangement.arrangement_items.create!(agency: @agency, departure: @departure)
    @version.arrangement_item_definitions.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      arrangement_item: item, name: "Airport transfer", category: "ground_transportation",
      capacity_management: "unmanaged", default_service_provider: @contractor, position: 2
    )
    occurrence = item.service_occurrences.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement, status: "planned"
    )
    definition = @version.service_occurrence_definitions.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      arrangement_item: item, service_occurrence: occurrence, name: "Transfer",
      starts_on: Date.new(2026, 6, 1), ends_on: Date.new(2026, 6, 1),
      time_zone: "America/New_York", service_provider: @contractor
    )
    { item: item, occurrence_definition: definition }
  end
end
