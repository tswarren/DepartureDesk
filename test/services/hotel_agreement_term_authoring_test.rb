# frozen_string_literal: true

require "test_helper"

class HotelAgreementTermAuthoringTest < ActiveSupport::TestCase
  SOURCE = "Hilton agreement"

  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @contractor = create_capacity_supplier(@agency, "Hilton Fort Lauderdale Marina")
    @departure = create_capacity_departure(@agency, name: "Smith Family Reunion")
    @departure.update!(time_zone: "America/New_York")
    @graph = create_capacity_graph(
      agency: @agency, departure: @departure, contractor: @contractor,
      provider: @contractor, prefix: "Hilton", category: "lodging"
    )
    @arrangement = @graph[:arrangement]
    @version = @graph[:version]
    @item = @graph[:item]
  end

  test "each optional kind can be created, updated, and removed on this stay" do
    SupplierAgreementReference::OPTIONAL_KINDS.each do |kind|
      created = record(kind: kind, scope: "stay", governing_wording: wording_for(kind))
      assert_equal :created, created.status
      assert_equal @item.id, created.record.arrangement_item_id
      assert_nil created.record.original_wording

      updated = record(
        kind: kind, scope: "stay", governing_wording: "#{wording_for(kind)} Revised.",
        lock_version: created.record.lock_version, idempotency_key: SecureRandom.uuid
      )
      assert_equal :updated, updated.status
      assert_equal "#{wording_for(kind)} Revised.", updated.record.governing_wording

      removed = RemoveSupplierAgreementReference.new(
        agency: @agency, actor: @admin, reference: updated.record, lock_version: updated.record.lock_version
      ).call
      assert_equal :destroyed, removed.status
      assert_nil @version.supplier_agreement_references.find_by(kind: kind)
    end

    assert_equal 0, @version.supplier_deposit_requirement_definitions.count
    assert_equal 0, @version.supplier_deadline_definitions.count
  end

  test "optional kinds accept one explicit scope and reject the other" do
    wide = record(
      kind: "destination_fee", scope: "agreement", governing_wording: wording_for("destination_fee"),
      supplier_arrangement_version: @version
    )
    assert_nil wide.record.arrangement_item_id

    other_scope = assert_raises(AgencyCommand::Error) do
      record(kind: "destination_fee", scope: "stay", governing_wording: "Stay wording.", idempotency_key: SecureRandom.uuid)
    end
    assert_equal :invalid, other_scope.code
    assert_equal 1, @version.supplier_agreement_references.where(kind: "destination_fee").count

    RemoveSupplierAgreementReference.new(
      agency: @agency, actor: @admin, reference: wide.record.reload, lock_version: wide.record.lock_version
    ).call
    stay = record(kind: "additional_nights", scope: "stay", governing_wording: wording_for("additional_nights"))
    database_rejection = assert_raises(ActiveRecord::StatementInvalid) do
      SupplierAgreementReference.transaction(requires_new: true) do
        @version.supplier_agreement_references.create!(
          agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
          arrangement_item: nil, kind: "additional_nights",
          governing_wording: "Agreement-wide nights.", source_description: SOURCE,
          recorded_by: @admin, recorded_at: Time.current
        )
      end
    end
    assert_match "both Item scope and agreement-wide scope", database_rejection.message
    assert_equal stay.record.id, @version.supplier_agreement_references.find_by(kind: "additional_nights").id
  end

  test "the first three kinds reject a version-wide row" do
    error = assert_raises(AgencyCommand::Error) do
      record(
        kind: "deposit_derivation", scope: "agreement", governing_wording: "Derived from the block.",
        supplier_arrangement_version: @version
      )
    end
    assert_equal :invalid, error.code

    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierAgreementReference.transaction(requires_new: true) do
        SupplierAgreementReference.insert_all!([ {
          agency_id: @agency.id,
          departure_id: @departure.id,
          supplier_arrangement_id: @arrangement.id,
          supplier_arrangement_version_id: @version.id,
          arrangement_item_id: nil,
          kind: "attrition",
          governing_wording: "Version-wide attrition.",
          source_description: SOURCE,
          recorded_by_id: @admin.id,
          recorded_at: Time.current,
          created_at: Time.current,
          updated_at: Time.current
        } ])
      end
    end
  end

  test "an agreement-wide term is one row on every Hotel stay" do
    created = record(
      kind: "cancellation", scope: "agreement", governing_wording: wording_for("cancellation"),
      supplier_arrangement_version: @version
    )
    other = @arrangement.arrangement_items.create!(agency: @agency, departure: @departure)
    @version.arrangement_item_definitions.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      arrangement_item: other, name: "Second stay", category: "lodging",
      capacity_management: "managed", default_service_provider: @contractor, position: 2
    )

    first = compile(@item).terms.find { |term| term.kind == "cancellation" }
    second = compile(other).terms.find { |term| term.kind == "cancellation" }
    assert first.agreement_wide
    assert second.agreement_wide
    assert_equal created.record.id, first.reference.id
    assert_equal created.record.id, second.reference.id
    assert_equal 1, @version.supplier_agreement_references.where(kind: "cancellation").count
  end

  test "source defaults follow shared provenance and an override stays on one row" do
    record(kind: "destination_fee", scope: "stay", governing_wording: wording_for("destination_fee"), supplier_reference: "G-100")
    nights = record(
      kind: "additional_nights", scope: "stay", governing_wording: wording_for("additional_nights"),
      supplier_reference: "G-100", idempotency_key: SecureRandom.uuid
    )
    shared = compile(@item).source_default
    assert_equal SOURCE, shared.source_description
    assert_equal "G-100", shared.supplier_reference

    record(
      kind: "destination_fee", scope: "stay", governing_wording: wording_for("destination_fee"),
      source_description: "Revised Hilton letter", supplier_reference: "G-200",
      lock_version: @version.supplier_agreement_references.find_by!(kind: "destination_fee").lock_version,
      idempotency_key: SecureRandom.uuid
    )
    assert_equal "G-100", nights.record.reload.supplier_reference
    assert_nil compile(@item).source_default
  end

  test "supplier confirmation freezes the new kinds" do
    reference = record(kind: "early_departure", scope: "stay", governing_wording: wording_for("early_departure")).record
    SupplierConfirmation.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version, confirming_supplier: @contractor,
      actor: @admin, evidence_kind: "supplier_confirmation", evidence_on: Date.new(2026, 9, 28),
      channel: "email", reference_note: "Confirmed the Hotel terms.",
      confirmed_without_identifier_reason: "No hotel number was issued.", recorded_at: Time.current
    )

    [ :create, :update ].each do |action|
      error = assert_raises(AgencyCommand::Error) do
        record(
          kind: action == :create ? "cancellation" : "early_departure",
          scope: "stay",
          governing_wording: "After confirmation.",
          lock_version: action == :update ? reference.lock_version : nil,
          idempotency_key: SecureRandom.uuid
        )
      end
      assert_equal :invalid_state, error.code
    end
    removed = assert_raises(AgencyCommand::Error) do
      RemoveSupplierAgreementReference.new(
        agency: @agency, actor: @admin, reference: reference, lock_version: reference.lock_version
      ).call
    end
    assert_equal :invalid_state, removed.code
    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierAgreementReference.transaction(requires_new: true) do
        reference.update_columns(governing_wording: "Bypassed edit.")
      end
    end
    assert_equal wording_for("early_departure"), reference.reload.governing_wording
  end

  test "a successor copy can be removed and activation readiness still requires it" do
    created = record(kind: "destination_fee", scope: "stay", governing_wording: wording_for("destination_fee"))
    @departure.update!(status: "active", departure_reference: "D-930210", first_activated_at: Time.current)
    @version.update!(status: "activated", activated_at: Time.current)
    @arrangement.update!(status: "active", governing_version: @version)
    successor = CreateSupplierArrangementSuccessor.new(
      agency: @agency, actor: @admin, arrangement: @arrangement.reload,
      arrangement_lock_version: @arrangement.lock_version, version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
    copied = successor.supplier_agreement_references.find_by!(kind: "destination_fee")
    assert_equal created.record.id, copied.copied_from_id
    assert_equal wording_for("destination_fee"), copied.governing_wording

    revised = record(
      kind: "destination_fee", scope: "stay", governing_wording: "#{wording_for("destination_fee")} Successor.",
      arrangement_item: @item, lock_version: copied.lock_version, idempotency_key: SecureRandom.uuid
    )
    assert_equal wording_for("destination_fee"), created.record.reload.governing_wording
    assert_equal "#{wording_for("destination_fee")} Successor.", revised.record.governing_wording

    RemoveSupplierAgreementReference.new(
      agency: @agency, actor: @admin, reference: copied.reload, lock_version: copied.reload.lock_version
    ).call
    readiness = SupplierArrangementActivationReadiness.new(
      agency: @agency, arrangement: @arrangement, version: successor
    ).call
    assert_includes readiness.blockers.map(&:code), :copied_lineage_invalid
    assert_equal wording_for("destination_fee"), created.record.reload.governing_wording
    missing = HotelAgreementWorkspace.new(
      agency: @agency, departure: @departure, arrangement: @arrangement, version: successor, item: @item
    ).call.findings
    assert_includes missing, "Copied Destination Fee is missing from this successor."
  end

  test "recording a term audits identity without the wording" do
    record(kind: "cancellation", scope: "stay", governing_wording: wording_for("cancellation"))
    recorded = AuditEvent.where(action: "supplier_arrangement.agreement_reference_recorded").order(:created_at).last
    assert_equal %w[
      arrangement_item_id kind supplier_agreement_reference_id
      supplier_arrangement_id supplier_arrangement_version_id
    ], recorded.details.keys.sort
    assert recorded.details.values.none? { |value| value.to_s.include?("Cancellation follows") }

    reference = @version.supplier_agreement_references.find_by!(kind: "cancellation")
    RemoveSupplierAgreementReference.new(
      agency: @agency, actor: @admin, reference: reference, lock_version: reference.lock_version
    ).call
    removed = AuditEvent.where(action: "supplier_arrangement.agreement_reference_removed").order(:created_at).last
    assert_equal reference.id, removed.details["supplier_agreement_reference_id"]
    assert removed.details.values.none? { |value| value.to_s.include?("Cancellation follows") }
  end

  test "idempotency, stale locks, viewers, and other agencies stay closed" do
    key = SecureRandom.uuid
    created = record(kind: "cancellation", scope: "stay", governing_wording: wording_for("cancellation"), idempotency_key: key)
    replay = record(kind: "cancellation", scope: "stay", governing_wording: wording_for("cancellation"), idempotency_key: key)
    assert_equal :replayed, replay.status
    assert_equal created.record.id, replay.record.id

    stale = assert_raises(AgencyCommand::Error) do
      record(
        kind: "cancellation", scope: "stay", governing_wording: "Changed.",
        lock_version: created.record.lock_version + 5, idempotency_key: SecureRandom.uuid
      )
    end
    assert_equal :conflict, stale.code

    viewer = assert_raises(AgencyCommand::Error) do
      RecordSupplierAgreementReference.new(
        agency: @agency, actor: agency_users(:harbor_viewer), arrangement_item: @item,
        scope: "stay", kind: "early_departure", governing_wording: wording_for("early_departure"),
        source_description: SOURCE, idempotency_key: SecureRandom.uuid
      ).call
    end
    assert_equal :unauthorized, viewer.code

    assert_raises(ActiveRecord::RecordNotFound) do
      RecordSupplierAgreementReference.new(
        agency: agencies(:cove), actor: agency_users(:cove_admin), arrangement_item: @item,
        scope: "agreement", supplier_arrangement_version: @version, kind: "cancellation",
        governing_wording: wording_for("cancellation"), source_description: SOURCE,
        idempotency_key: SecureRandom.uuid
      ).call
    end
  end

  test "reviewed none is scoped and exclusive with wording" do
    recorded = RecordSupplierAgreementReferenceAbsence.new(
      agency: @agency, actor: @admin, arrangement_item: @item, scope: "stay", kind: "cancellation",
      idempotency_key: SecureRandom.uuid
    ).call
    assert_equal :created, recorded.status
    assert_equal "Reviewed — none", compile(@item).terms.find { |term| term.kind == "cancellation" }.state

    wording = assert_raises(AgencyCommand::Error) do
      record(kind: "cancellation", scope: "stay", governing_wording: wording_for("cancellation"), idempotency_key: SecureRandom.uuid)
    end
    assert_equal :invalid, wording.code

    item_kind = assert_raises(AgencyCommand::Error) do
      RecordSupplierAgreementReferenceAbsence.new(
        agency: @agency, actor: @admin, arrangement_item: @item, scope: "stay", kind: "attrition",
        idempotency_key: SecureRandom.uuid
      ).call
    end
    assert_equal :invalid, item_kind.code

    RemoveSupplierAgreementReferenceAbsence.new(
      agency: @agency, actor: @admin, absence: recorded.record, lock_version: recorded.record.lock_version
    ).call
    wide = RecordSupplierAgreementReferenceAbsence.new(
      agency: @agency, actor: @admin, supplier_arrangement_version: @version, scope: "agreement",
      kind: "early_departure", idempotency_key: SecureRandom.uuid
    ).call
    assert_nil wide.record.arrangement_item_id
    assert_equal "Reviewed — none", compile(@item).terms.find { |term| term.kind == "early_departure" }.state

    SupplierConfirmation.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version, confirming_supplier: @contractor,
      actor: @admin, evidence_kind: "supplier_confirmation", evidence_on: Date.new(2026, 9, 28),
      channel: "email", reference_note: "Confirmed the Hotel terms.",
      confirmed_without_identifier_reason: "No hotel number was issued.", recorded_at: Time.current
    )
    frozen = assert_raises(AgencyCommand::Error) do
      RecordSupplierAgreementReferenceAbsence.new(
        agency: @agency, actor: @admin, arrangement_item: @item, scope: "stay", kind: "destination_fee",
        idempotency_key: SecureRandom.uuid
      ).call
    end
    assert_equal :invalid_state, frozen.code
  end

  private

  def wording_for(kind)
    {
      "destination_fee" => "The $150 destination fee is waived.",
      "additional_nights" => "Additional nights November 1 through November 3 are available on request.",
      "early_departure" => "Early departure follows the Hotel's governing provision.",
      "cancellation" => "Cancellation follows the Hotel's governing provision."
    }.fetch(kind)
  end

  def record(kind:, governing_wording:, scope: "stay", source_description: SOURCE, supplier_reference: nil,
    supplier_arrangement_version: nil, arrangement_item: @item, lock_version: nil, idempotency_key: nil)
    RecordSupplierAgreementReference.new(
      agency: @agency, actor: @admin, arrangement_item: scope == "agreement" ? nil : arrangement_item,
      supplier_arrangement_version: supplier_arrangement_version, scope: scope, kind: kind,
      governing_wording: governing_wording, source_description: source_description,
      supplier_reference: supplier_reference, lock_version: lock_version,
      idempotency_key: idempotency_key || SecureRandom.uuid
    ).call
  end

  def compile(item)
    HotelAgreementWorkspace.new(
      agency: @agency, departure: @departure, arrangement: @arrangement, version: @version, item: item
    ).call
  end
end
