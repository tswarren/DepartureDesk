# frozen_string_literal: true

require "test_helper"

class M3e5rIdempotencyCompositeFkConstraintsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @other = agencies(:cove)
    @actor = agency_users(:harbor_staff)
    @other_key = @other.agency_command_idempotency_keys.create!(
      command_name: "CrossAgencyProbe",
      idempotency_key: SecureRandom.uuid,
      payload_digest: "sha256:#{SecureRandom.hex(32)}",
      result_record_type: "Probe",
      result_record_id: SecureRandom.uuid
    )
    @same_key = @agency.agency_command_idempotency_keys.create!(
      command_name: "SameAgencyProbe",
      idempotency_key: SecureRandom.uuid,
      payload_digest: "sha256:#{SecureRandom.hex(32)}",
      result_record_type: "Probe",
      result_record_id: SecureRandom.uuid
    )

    @supplier = create_capacity_supplier(@agency, "M3E5R Supplier")
    @departure = create_capacity_departure(
      @agency, name: "M3E5R Departure", status: "draft"
    )
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current,
      starts_on: Date.new(2027, 6, 15),
      ends_on: Date.new(2027, 6, 22),
      time_zone: "America/New_York",
      operating_currency: "USD"
    )
    @graph = create_capacity_graph(
      agency: @agency, departure: @departure,
      contractor: @supplier, provider: @supplier,
      prefix: "M3E5R", capacity_management: "unmanaged"
    )
    @arrangement = @graph[:arrangement]
    @version = @graph[:version]
    @cost_source = create_cost_source!("Primary", 100_000, 10_000, 1)
    @second_cost_source = create_cost_source!("Secondary", 50_000, 5_000, 2)
    create_confirmation_trigger!
    create_deposit!(5_000, "2027-05-01")
    create_deposit!(2_500, "2027-05-15")
    activate_arrangement!

    commitments = SupplierCommitment.where(
      opening_kind: "deposit_requirement",
      supplier_arrangement: @arrangement
    ).order(:id).to_a
    @first_commitment = commitments.fetch(0)
    @second_commitment = commitments.fetch(1)

    @attestation = AttestSupplierDepositHandledExternally.new(
      agency: @agency, actor: @actor, commitment: @first_commitment,
      note: "Wire transfer confirmed with supplier finance",
      confirmed_complete: true,
      idempotency_key: SecureRandom.uuid
    ).call.record

    @milestone = RecordSupplierPlanningMilestone.new(
      agency: @agency, actor: @actor, arrangement: @arrangement,
      version: @version.reload,
      kind: "names_assigned_to_supplier",
      occurred_on: Date.current,
      note: "Names delivered",
      idempotency_key: SecureRandom.uuid
    ).call.record

    QualifySupplierContingentExposure.new(
      agency: @agency, actor: @actor, arrangement: @arrangement,
      cost_source: @cost_source,
      note: "Minimum enrollment reached with supplier confirmation",
      idempotency_key: SecureRandom.uuid
    ).call
  end

  test "deposit attestation idempotency FK rejects cross-agency key and accepts same-agency" do
    template = @attestation
    base = {
      agency_id: template.agency_id,
      departure_id: template.departure_id,
      supplier_arrangement_id: template.supplier_arrangement_id,
      supplier_arrangement_version_id: template.supplier_arrangement_version_id,
      supplier_deposit_requirement_tranche_id: @second_commitment.supplier_deposit_requirement_tranche_id,
      supplier_commitment_id: @second_commitment.id,
      attested_amount_minor_units: @second_commitment.amount_minor_units || 2_500,
      currency: template.currency,
      confirmed_complete: true,
      note: "Second attestation",
      actor_id: template.actor_id,
      occurred_at: Time.current,
      recorded_at: Time.current
    }

    assert_raises(ActiveRecord::InvalidForeignKey) do
      ActiveRecord::Base.transaction(requires_new: true) do
        insert_row!("supplier_deposit_external_attestations", base.merge(
          agency_command_idempotency_key_id: @other_key.id
        ))
      end
    end

    assert_nothing_raised do
      insert_row!("supplier_deposit_external_attestations", base.merge(
        agency_command_idempotency_key_id: @same_key.id
      ))
    end
  end

  test "planning milestone idempotency FK rejects cross-agency key and accepts same-agency" do
    template = @milestone
    base = {
      agency_id: template.agency_id,
      departure_id: template.departure_id,
      supplier_arrangement_id: template.supplier_arrangement_id,
      supplier_arrangement_version_id: template.supplier_arrangement_version_id,
      kind: template.kind,
      occurred_on: Date.current - 1,
      occurred_at: nil,
      actor_id: template.actor_id,
      note: "Second milestone note",
      recorded_at: Time.current
    }

    assert_raises(ActiveRecord::InvalidForeignKey) do
      ActiveRecord::Base.transaction(requires_new: true) do
        insert_row!("supplier_planning_milestone_occurrences", base.merge(
          agency_command_idempotency_key_id: @other_key.id
        ))
      end
    end

    assert_nothing_raised do
      insert_row!("supplier_planning_milestone_occurrences", base.merge(
        agency_command_idempotency_key_id: @same_key.id
      ))
    end
  end

  test "exposure qualification idempotency FK rejects cross-agency key and accepts same-agency" do
    template = SupplierExposureSourceQualification.find_by!(
      supplier_arrangement: @arrangement, source_id: @cost_source.id
    )
    base = {
      agency_id: template.agency_id,
      departure_id: template.departure_id,
      supplier_arrangement_id: template.supplier_arrangement_id,
      supplier_arrangement_version_id: template.supplier_arrangement_version_id,
      source_kind: template.source_kind,
      source_id: @second_cost_source.id,
      qualification_band: template.qualification_band,
      qualification_reason: template.qualification_reason,
      note: "Second source qualified",
      actor_id: template.actor_id,
      recorded_at: Time.current,
      lock_version: 0
    }

    assert_raises(ActiveRecord::InvalidForeignKey) do
      ActiveRecord::Base.transaction(requires_new: true) do
        insert_row!("supplier_exposure_source_qualifications", base.merge(
          agency_command_idempotency_key_id: @other_key.id
        ))
      end
    end

    assert_nothing_raised do
      insert_row!("supplier_exposure_source_qualifications", base.merge(
        agency_command_idempotency_key_id: @same_key.id
      ))
    end
  end

  private

  def insert_row!(table, attributes)
    id = SecureRandom.uuid_v7
    columns = [ "id", *attributes.keys.map(&:to_s), "created_at", "updated_at" ]
    values = [
      quote_value(id),
      *attributes.values.map { |value| quote_value(value) },
      "CURRENT_TIMESTAMP",
      "CURRENT_TIMESTAMP"
    ]
    ActiveRecord::Base.connection.execute(<<~SQL.squish)
      INSERT INTO #{table} (#{columns.join(", ")})
      VALUES (#{values.join(", ")})
    SQL
  end

  def create_cost_source!(label, amount, commission, position)
    source = SupplierCostSource.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      arrangement_item: @graph[:item],
      charging_supplier: @supplier,
      label: "M3E5R #{label}", position:
    )
    definition = SupplierCostDefinition.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      supplier_cost_source: source,
      stage: "contracted", status: "forecast_ready", mode: "calculated",
      currency: "USD",
      forecast_ready_by: @actor, forecast_ready_at: Time.current,
      readiness_fingerprint: "sha256:m3e5r-#{position}",
      readiness_provenance: "Signed terms"
    )
    SupplierCostComponent.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      supplier_cost_definition: definition,
      label: "Fare", economic_role: "supplier_charge",
      calculation_kind: "fixed", amount_minor_units: amount,
      pass_through: false, position: 1
    )
    SupplierCostComponent.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      supplier_cost_definition: definition,
      label: "Commission", economic_role: "expected_commission",
      calculation_kind: "fixed", amount_minor_units: commission,
      pass_through: false, position: 2
    )
    definition.update!(
      readiness_fingerprint: SupplierCostDefinitionFingerprint.call(definition.reload)
    )
    source
  end

  def create_confirmation_trigger!
    SupplierCommitmentTriggerDefinition.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      committed_supplier: @supplier,
      trigger_kind: "arrangement_confirmation",
      authority_shape: "fixed_quantity",
      description: "Confirm cabins",
      fixed_quantity: 1,
      quantity_basis: "resource_units",
      position: 1
    )
  end

  def create_deposit!(amount, date)
    CreateSupplierDepositRequirementDefinition.new(
      agency: @agency, actor: @actor, version: @version.reload,
      attributes: {
        amount_shape: "fixed_amount",
        fixed_amount_minor_units: amount,
        currency: "USD",
        rule_shape: "fixed_date",
        rule_parameters: { "date" => date },
        precision: "date_only",
        time_zone: "America/New_York",
        coverage_links: [],
        cost_links: []
      },
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
  end

  def activate_arrangement!
    ActivateSupplierArrangementVersion.new(
      agency: @agency, actor: @actor, arrangement: @arrangement,
      version: @version.reload,
      arrangement_lock_version: @arrangement.reload.lock_version,
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid,
      evidence_attributes: {
        evidence_kind: "supplier_confirmation", evidence_on: Date.current,
        channel: "portal", reference_note: "Supplier approved exact terms",
        confirmed_without_identifier_reason: "Supplier did not issue one"
      },
      cost_source_coverage_acknowledged: true,
      provisional_costs_acknowledged: true,
      commitment_trigger_coverage_acknowledged: true,
      elapsed_deadlines_acknowledged: false
    ).call
  end

  def quote_value(value)
    ActiveRecord::Base.connection.quote(value)
  end
end
