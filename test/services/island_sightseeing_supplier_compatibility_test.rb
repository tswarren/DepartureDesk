# frozen_string_literal: true

require "test_helper"

class IslandSightseeingSupplierCompatibilityTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @office = offices(:harbor_main)
    @agency.reference_sequences.find_or_create_by!(namespace: ReferenceSequence::SUPPLIER_NAMESPACE) do |sequence|
      sequence.next_value = 1
    end
    @supplier = CreateSupplier.new(
      agency: @agency, actor: @admin, kind: "organization",
      names: { display_name: "Port Promotions" },
      categories: [ "activity_attraction" ]
    ).call.record
    @departure = CreateDeparture.new(
      agency: @agency, actor: @admin,
      attributes: {
        name: "Smith Family Reunion",
        starts_on: Date.new(2027, 11, 6),
        ends_on: Date.new(2027, 11, 13),
        time_zone: "America/New_York",
        operating_currency: "USD",
        responsible_office_id: @office.id,
        responsible_agency_user_id: @admin.id
      },
      current_office: @office
    ).call.record
    @arrangement = CreateSupplierArrangement.new(
      agency: @agency, actor: @admin, departure: @departure,
      idempotency_key: SecureRandom.uuid,
      attributes: { name: "Port Promotions", contracting_supplier_id: @supplier.id }
    ).call.record
    @version = @arrangement.versions.sole
  end

  test "shipped supplier commands store the excursion and expose the named limits" do
    sightseeing = create_item("Island Sightseeing")
    second = create_item("Harbor sail")
    mark_managed!(sightseeing)
    resource = create_resource(sightseeing)
    occurrence = create_occurrence(sightseeing)
    definition = occurrence_definition(occurrence)

    assert_equal %w[activity_attraction activity_attraction], item_categories
    assert_not ArrangementItemDefinition::CATEGORIES.include?("excursion")
    assert_equal Date.new(2027, 11, 8), definition.starts_on
    assert_equal Date.new(2027, 11, 8), definition.ends_on
    assert_equal [ 9, 30 ], local_time(definition, :starts_at_local)
    assert_equal [ 15, 0 ], local_time(definition, :ends_at_local)
    assert_equal "America/Nassau", definition.time_zone
    assert_equal "CocoCay, Bahamas", definition.origin_name
    assert_equal "CocoCay, Bahamas", definition.destination_name
    assert_nil resource_definition(resource).maximum_occupancy
    assert_not ServiceOffer.exists?(departure_id: @departure.id)

    ClassifyCapacityPair.new(
      agency: @agency, actor: @admin, item: sightseeing,
      service_occurrence: occurrence, supplier_resource: resource,
      classification: "pooled", version_lock_version: lock_version
    ).call
    ConfigureCapacityPairWithPool.new(
      agency: @agency, actor: @admin, item: sightseeing,
      service_occurrence: occurrence, supplier_resource: resource,
      version_lock_version: lock_version, idempotency_key: SecureRandom.uuid,
      pool_attributes: {
        inventory_mode: "block", measurement_basis: "traveler_positions",
        unit_label: "participants", label: "Island Sightseeing participants",
        proposed_opening_quantity: 40, evidence_kind: "contract",
        evidence_on: "2026-10-02", evidence_reference_note: "Port Promotions group spaces"
      }
    ).call
    pool = @version.capacity_pool_definitions.find_by!(arrangement_item: sightseeing).capacity_pool
    assert_equal "traveler_positions", pool.measurement_basis
    assert_equal "block", pool.inventory_mode
    assert_equal 40, @version.capacity_pool_definitions.find_by!(capacity_pool: pool).proposed_opening_quantity

    assumption = CreateSupplierCostUsageAssumption.new(
      agency: @agency, actor: @admin, arrangement_item: sightseeing,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        expected_persons: 5, service_occurrence_id: occurrence.id, supplier_resource_id: resource.id
      }
    ).call.record
    source = CreateSupplierCostSource.new(
      agency: @agency, actor: @admin, arrangement: @arrangement,
      version_lock_version: lock_version, idempotency_key: SecureRandom.uuid,
      attributes: {
        arrangement_item_id: sightseeing.id, service_occurrence_id: occurrence.id,
        supplier_resource_id: resource.id, charging_supplier_id: @supplier.id,
        label: "Island Sightseeing"
      }
    ).call.record
    cost_definition = CreateSupplierCostDefinition.new(
      agency: @agency, actor: @admin, source: source, source_lock_version: source.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: { stage: "contracted", mode: "calculated", currency: "USD" }
    ).call.record
    rate = CreateSupplierCostComponent.new(
      agency: @agency, actor: @admin, definition: cost_definition,
      definition_lock_version: cost_definition.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: {
        label: "Per confirmed participant", economic_role: "supplier_charge",
        calculation_kind: "unit_rate", quantity_basis: "persons",
        amount_minor_units: 5_000, pass_through: false
      }
    ).call.record
    MarkCostDefinitionForecastReady.new(
      agency: @agency, actor: @admin, definition: cost_definition.reload,
      lock_version: cost_definition.lock_version,
      readiness_provenance: "Port Promotions per confirmed participant"
    ).call

    assert_equal 25_000, forecast_total
    update_persons!(assumption, 4)
    assert_equal 20_000, forecast_total
    assert_equal 40, @version.capacity_pool_definitions.find_by!(capacity_pool: pool).proposed_opening_quantity

    shortfall = CreateSupplierCostComponent.new(
      agency: @agency, actor: @admin, definition: cost_definition.reload,
      definition_lock_version: cost_definition.lock_version, idempotency_key: SecureRandom.uuid,
      base_links: [ { base_component_id: rate.id, direction: "add" } ],
      attributes: {
        label: "Minimum five", economic_role: "supplier_charge",
        calculation_kind: "minimum_quantity_shortfall", minimum_quantity: 5,
        quantity_basis: "persons", pass_through: false
      }
    ).call.record
    MarkCostDefinitionForecastReady.new(
      agency: @agency, actor: @admin, definition: cost_definition.reload,
      lock_version: cost_definition.lock_version,
      readiness_provenance: "Port Promotions minimum shortfall probe"
    ).call
    assert_equal 25_000, forecast_total
    shortfall.supplier_cost_component_bases.each(&:destroy!)
    shortfall.reload.destroy!
    MarkCostDefinitionForecastReady.new(
      agency: @agency, actor: @admin, definition: cost_definition.reload,
      lock_version: cost_definition.lock_version,
      readiness_provenance: "Port Promotions per confirmed participant"
    ).call
    assert_equal 20_000, forecast_total
    assert_equal [ "Per confirmed participant" ], cost_definition.reload.supplier_cost_components.order(:position).pluck(:label)

    assert_raises(ActiveRecord::StatementInvalid) do
      rate.update!(quantity_capacity_pool_id: pool.id)
    end
    assert_nil rate.reload.quantity_capacity_pool_id

    update_persons!(assumption, 20)
    assert_equal 100_000, forecast_total
    update_persons!(assumption, 40)
    assert_equal 200_000, forecast_total
    update_persons!(assumption, 4)

    final_count = create_deadline!(sightseeing, "final_count_due", "2027-11-01")
    cutoff = create_deadline!(sightseeing, "cancellation_cutoff", "2027-11-01")
    review = create_deadline!(sightseeing, "other", "2027-11-01", other_label: "Minimum-enrollment review")
    assert_equal [ "2027-11-01" ], [ final_count, cutoff, review ].map { |row| row.rule_parameters["date"] }.uniq
    assert_equal 3, @version.supplier_deadline_definitions.count
    assert_not SupplierDeadlineDefinition::DEADLINE_TYPES.include?("payment_due")
    assert_empty final_count.supplier_deadline_commitment_definition_lines
    assert_equal "Minimum-enrollment review", review.other_label

    SupplierDepositRequirementDefinition.transaction(requires_new: true) do
      deposit = CreateSupplierDepositRequirementDefinition.new(
        agency: @agency, actor: @admin, version: @version.reload,
        version_lock_version: lock_version, idempotency_key: SecureRandom.uuid,
        attributes: {
          amount_shape: "quantity_times_rate", currency: "USD",
          rate_minor_units: 5_000, quantity_basis: "capacity_pool_units",
          rule_shape: "fixed_date", rule_parameters: { "date" => "2027-11-01" },
          precision: "date_only", time_zone: "America/Nassau",
          coverage_links: [ {
            arrangement_item_id: sightseeing.id, service_occurrence_id: occurrence.id,
            supplier_resource_id: resource.id, capacity_pool_id: pool.id
          } ],
          cost_links: [], contributor_definition_ids: []
        }
      ).call.record
      preview = SupplierDepositAmountEvaluator.call(
        definition: deposit, version: @version.reload, arrangement: @arrangement, mode: :preview
      )
      assert_equal 40, preview[:inputs]["quantity"]
      assert_equal 200_000, preview[:amount_minor_units]
      raise ActiveRecord::Rollback
    end
    assert_empty @version.reload.supplier_deposit_requirement_definitions

    reference = RecordSupplierAgreementReference.new(
      agency: @agency, actor: @admin, kind: "cancellation", scope: "stay",
      arrangement_item: sightseeing, supplier_arrangement_version: @version,
      governing_wording: "Beginning November 1, 2027, confirmed participation is non-cancellable and non-refundable. Enrollment below five does not cancel the activity; Port Promotions decides whether it will operate.",
      source_description: "Port Promotions Island Sightseeing",
      idempotency_key: SecureRandom.uuid
    ).call.record
    assert_equal "cancellation", reference.kind
    assert_equal sightseeing.id, reference.arrangement_item_id
    assert_nil reference.original_wording

    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
    activation_error = assert_raises(AgencyCommand::Error) do
      ActivateSupplierArrangementVersion.new(
        agency: @agency, actor: @admin, arrangement: @arrangement, version: @version.reload,
        arrangement_lock_version: @arrangement.reload.lock_version,
        version_lock_version: @version.lock_version,
        idempotency_key: SecureRandom.uuid,
        evidence_attributes: {
          evidence_kind: "supplier_confirmation", evidence_on: Date.current,
          channel: "email", reference_note: "Port Promotions activation",
          confirmed_without_identifier_reason: "No file number yet"
        },
        cost_source_coverage_acknowledged: true,
        provisional_costs_acknowledged: false,
        commitment_trigger_coverage_acknowledged: true,
        elapsed_deadlines_acknowledged: false
      ).call
    end
    assert_match(/Every retained Item requires an Item-level Supplier cost source/, activation_error.message)
    second_definition = @version.arrangement_item_definitions.find_by!(arrangement_item: second)
    second_definition.destroy!
    second.destroy!

    RecordSupplierConfirmationEvidence.new(
      agency: @agency, actor: @admin, arrangement: @arrangement, version: @version.reload,
      recorded_at: Time.current,
      evidence_attributes: {
        evidence_kind: "supplier_confirmation", evidence_on: Date.current,
        channel: "email", reference_note: "Port Promotions confirmed the activity",
        confirmed_without_identifier_reason: "No file number yet"
      }
    ).call
    assert_raises(ActiveRecord::RecordInvalid) do
      definition.update!(name: "Island Sightseeing confirmed")
    end
    assert_equal "Island Sightseeing", definition.reload.name

    activation = ActivateSupplierArrangementVersion.new(
      agency: @agency, actor: @admin, arrangement: @arrangement, version: @version.reload,
      arrangement_lock_version: @arrangement.reload.lock_version,
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid,
      evidence_attributes: {
        evidence_kind: "supplier_confirmation", evidence_on: Date.current,
        channel: "email", reference_note: "Port Promotions activation",
        confirmed_without_identifier_reason: "No file number yet"
      },
      cost_source_coverage_acknowledged: true,
      provisional_costs_acknowledged: false,
      commitment_trigger_coverage_acknowledged: true,
      elapsed_deadlines_acknowledged: false
    ).call
    assert_equal :created, activation.status

    successor = CreateSupplierArrangementSuccessor.new(
      agency: @agency, actor: @admin, arrangement: @arrangement.reload,
      arrangement_lock_version: @arrangement.lock_version,
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    assert_equal [ sightseeing.id ], successor.record.arrangement_item_definitions.order(:position).pluck(:arrangement_item_id)
  end

  private

  def create_item(name)
    CreateArrangementItem.new(
      agency: @agency, actor: @admin, arrangement: @arrangement,
      version_lock_version: lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { name: name, category: "activity_attraction", default_service_provider_id: @supplier.id }
    ).call.record
  end

  def mark_managed!(item)
    definition = @version.arrangement_item_definitions.find_by!(arrangement_item: item)
    SetItemCapacityManagement.new(
      agency: @agency, actor: @admin, definition: definition,
      capacity_management: "managed", lock_version: definition.lock_version
    ).call
  end

  def create_resource(item)
    CreateSupplierResource.new(
      agency: @agency, actor: @admin, item: item,
      version_lock_version: lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { name: "Participant" }
    ).call.record
  end

  def create_occurrence(item)
    CreateServiceOccurrence.new(
      agency: @agency, actor: @admin, item: item,
      version_lock_version: lock_version, idempotency_key: SecureRandom.uuid,
      attributes: {
        name: "Island Sightseeing",
        starts_on: "2027-11-08", ends_on: "2027-11-08",
        starts_at_local: "09:30", ends_at_local: "15:00",
        time_zone: "America/Nassau",
        origin_name: "CocoCay, Bahamas", destination_name: "CocoCay, Bahamas",
        service_provider_id: @supplier.id
      }
    ).call.record
  end

  def create_deadline!(item, deadline_type, date, other_label: nil)
    CreateSupplierDeadlineDefinition.new(
      agency: @agency, actor: @admin, version: @version.reload,
      version_lock_version: lock_version, idempotency_key: SecureRandom.uuid,
      attributes: {
        deadline_type: deadline_type, other_label: other_label,
        kind: "informational", rule_shape: "fixed_date",
        rule_parameters: { "date" => date }, precision: "date_only",
        time_zone: "America/Nassau", cardinality: "one_shared",
        coverage_links: [ { arrangement_item_id: item.id } ],
        commitment_lines: []
      }
    ).call.record
  end

  def update_persons!(assumption, count)
    UpdateSupplierCostUsageAssumption.new(
      agency: @agency, actor: @admin, assumption: assumption.reload,
      lock_version: assumption.lock_version,
      attributes: { expected_persons: count }
    ).call
  end

  def forecast_total
    EvaluateSupplierCostForecast.new(
      agency: @agency, departure: @departure, arrangement: @arrangement, version: @version.reload
    ).call.totals.forecast_supplier_cost_minor_units
  end

  def occurrence_definition(occurrence)
    @version.service_occurrence_definitions.find_by!(service_occurrence: occurrence)
  end

  def resource_definition(resource)
    @version.supplier_resource_definitions.find_by!(supplier_resource: resource)
  end

  def local_time(definition, field)
    value = definition.public_send(field)
    [ value.hour, value.min ]
  end

  def item_categories
    @version.arrangement_item_definitions.order(:position).pluck(:category)
  end

  def lock_version
    @version.reload.lock_version
  end
end
