require "test_helper"

class SupersedeSupplierIssuedIdentifierTest < ActiveSupport::TestCase
  include CapacityGraphHelper

  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @supplier = create_capacity_supplier(@agency, "Identifier Supplier")
    @departure = create_capacity_departure(@agency, name: "Identifier Departure")
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
    @graph = create_capacity_graph(
      agency: @agency, departure: @departure,
      contractor: @supplier, provider: @supplier,
      prefix: "Identifier", capacity_management: "unmanaged"
    )
    @arrangement = @graph[:arrangement]
    @version = @graph[:version]
    @version.update!(status: "activated", activated_at: Time.current)
    @arrangement.update!(status: "active", governing_version: @version)
    @confirmation = SupplierConfirmation.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      confirming_supplier: @supplier,
      actor: @actor,
      recorded_at: Time.current,
      evidence_kind: "supplier_confirmation",
      evidence_on: Date.current,
      channel: "portal",
      reference_note: "Confirmed",
      confirmed_without_identifier_reason: nil
    )
    @prior = SupplierIssuedIdentifier.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier: @supplier,
      issuer_context: "cruise line",
      identifier_type: "group_number",
      display_value: "GRP-100",
      normalized_value: "grp-100",
      first_supplier_confirmation: @confirmation
    )
  end

  test "replacement insert stamps prior without application update and preserves other label" do
    other_confirmation = SupplierConfirmation.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      confirming_supplier: @supplier,
      actor: @actor,
      recorded_at: Time.current,
      evidence_kind: "supplier_confirmation",
      evidence_on: Date.current,
      channel: "portal",
      reference_note: "Correction",
      confirmed_without_identifier_reason: nil
    )
    other_prior = SupplierIssuedIdentifier.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier: @supplier,
      issuer_context: "cruise line",
      identifier_type: "other",
      other_type_label: "Internal allotment",
      display_value: "ALT-1",
      normalized_value: "alt-1",
      first_supplier_confirmation: @confirmation
    )

    key = SecureRandom.uuid
    result = SupersedeSupplierIssuedIdentifier.new(
      agency: @agency, actor: @actor, identifier: other_prior,
      confirmation: other_confirmation,
      attributes: { display_value: "ALT-2", issuer_context: "cruise line", identifier_type: "other" },
      idempotency_key: key
    ).call

    assert_equal :created, result.status
    replacement = result.record
    assert_equal other_prior.id, replacement.supersedes_id
    assert_nil replacement.superseded_at
    assert_equal "Internal allotment", replacement.other_type_label
    assert_equal other_prior.id, replacement.supersedes_id
    assert_predicate other_prior.reload.superseded_at, :present?
    assert_equal 1, SupplierIssuedIdentifier.current.where(supplier_arrangement_id: @arrangement.id, normalized_value: "alt-2").count
    assert_equal 0, SupplierIssuedIdentifier.current.where(id: other_prior.id).count

    replay = SupersedeSupplierIssuedIdentifier.new(
      agency: @agency, actor: @actor, identifier: other_prior,
      confirmation: other_confirmation,
      attributes: { display_value: "ALT-2", issuer_context: "cruise line", identifier_type: "other" },
      idempotency_key: key
    ).call
    assert_equal :replayed, replay.status
    assert_equal replacement.id, replay.record.id
  end

  test "confirmation from another arrangement version is rejected" do
    other_version = @arrangement.versions.create!(
      agency: @agency, departure: @departure,
      version_number: 2, status: "draft", copied_from: @version
    )
    foreign_confirmation = SupplierConfirmation.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: other_version,
      confirming_supplier: @supplier,
      actor: @actor,
      recorded_at: Time.current,
      evidence_kind: "supplier_confirmation",
      evidence_on: Date.current,
      channel: "portal",
      reference_note: "Wrong version",
      confirmed_without_identifier_reason: "n/a"
    )

    error = assert_raises(AgencyCommand::Error) do
      SupersedeSupplierIssuedIdentifier.new(
        agency: @agency, actor: @actor, identifier: @prior,
        confirmation: foreign_confirmation,
        attributes: { display_value: "GRP-200", issuer_context: "cruise line" },
        idempotency_key: SecureRandom.uuid
      ).call
    end
    assert_equal :invalid, error.code
    assert_nil @prior.reload.superseded_at
  end

  test "requested reservation scopes freeze target columns" do
    reservation = CreateSupplierReservation.new(
      agency: @agency, actor: @actor, arrangement: @arrangement,
      attributes: {
        booking_supplier_id: @supplier.id,
        supplier_arrangement_version_id: @version.id,
        scopes: [ { target_kind: "arrangement", label: "Whole" } ]
      },
      idempotency_key: SecureRandom.uuid
    ).call.record
    RecordSupplierReservationRequest.new(
      agency: @agency, actor: @actor, reservation: reservation,
      attributes: { channel: "email", reference_note: "Sent" },
      idempotency_key: SecureRandom.uuid
    ).call
    scope = reservation.revisions.where(status: "requested").sole.scopes.sole

    error = assert_raises(ActiveRecord::StatementInvalid) do
      scope.update_columns(label: "Mutated")
    end
    assert_match(/immutable|requested reservation scopes/i, error.message)
  end
end
