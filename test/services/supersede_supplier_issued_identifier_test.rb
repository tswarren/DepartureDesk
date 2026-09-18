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
    assert_predicate other_prior.reload.superseded_at, :present?
    assert SupplierConfirmationIdentifierLink.exists?(
      supplier_issued_identifier_id: replacement.id,
      supplier_confirmation_id: other_confirmation.id
    )
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

  test "reservation-owned identifier rejects confirmation that covers another reservation" do
    reservation_a = create_requested_reservation
    reservation_b = create_requested_reservation
    respond_reservation(reservation_a)
    respond_reservation(reservation_b)
    confirmation_b = SupplierConfirmationReservationResponseLink
      .find_by!(supplier_reservation_id: reservation_b.id).supplier_confirmation
    prior = SupplierIssuedIdentifier.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_reservation: reservation_a,
      supplier: @supplier,
      issuer_context: "cruise line",
      identifier_type: "group_number",
      display_value: "RSV-A",
      normalized_value: "rsv-a",
      first_supplier_confirmation: confirmation_b
    )

    error = assert_raises(AgencyCommand::Error) do
      SupersedeSupplierIssuedIdentifier.new(
        agency: @agency, actor: @actor, identifier: prior,
        confirmation: confirmation_b,
        attributes: { display_value: "RSV-A2", issuer_context: "cruise line" },
        idempotency_key: SecureRandom.uuid
      ).call
    end
    assert_equal :invalid, error.code
    assert_match(/owning Reservation/i, error.message)
  end

  test "arrangement supersession requires acknowledgement for reservation-owned collision" do
    reservation = create_requested_reservation
    respond_reservation(reservation)
    confirmation = SupplierConfirmationReservationResponseLink
      .find_by!(supplier_reservation_id: reservation.id).supplier_confirmation
    SupplierIssuedIdentifier.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_reservation: reservation,
      supplier: @supplier,
      issuer_context: "cruise line",
      identifier_type: "group_number",
      display_value: "GRP-COLLIDE",
      normalized_value: "grp-collide",
      first_supplier_confirmation: confirmation
    )

    error = assert_raises(AgencyCommand::DuplicateReviewRequired) do
      SupersedeSupplierIssuedIdentifier.new(
        agency: @agency, actor: @actor, identifier: @prior,
        confirmation: @confirmation,
        attributes: {
          display_value: "GRP-COLLIDE",
          issuer_context: "cruise line",
          identifier_type: "group_number"
        },
        idempotency_key: SecureRandom.uuid
      ).call
    end
    assert error.token.present?
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

  test "same normalized value supersession stamps prior before uniqueness check" do
    result = SupersedeSupplierIssuedIdentifier.new(
      agency: @agency, actor: @actor, identifier: @prior,
      confirmation: @confirmation,
      attributes: {
        display_value: "grp-100",
        issuer_context: "cruise line",
        identifier_type: "group_number"
      },
      idempotency_key: SecureRandom.uuid
    ).call

    assert_equal :created, result.status
    assert_equal "grp-100", result.record.display_value
    assert_equal "grp-100", result.record.normalized_value
    assert_equal @prior.id, result.record.supersedes_id
    assert_predicate @prior.reload.superseded_at, :present?
    assert_equal 1, SupplierIssuedIdentifier.current.where(
      supplier_arrangement_id: @arrangement.id, normalized_value: "grp-100"
    ).count
  end

  test "database rejects supersession that targets a different reservation owner" do
    reservation_a = create_requested_reservation
    reservation_b = create_requested_reservation
    respond_reservation(reservation_a)
    respond_reservation(reservation_b)
    confirmation_b = SupplierConfirmationReservationResponseLink
      .find_by!(supplier_reservation_id: reservation_b.id).supplier_confirmation
    prior_a = SupplierIssuedIdentifier.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_reservation: reservation_a,
      supplier: @supplier,
      issuer_context: "cruise line",
      identifier_type: "group_number",
      display_value: "OWN-A",
      normalized_value: "own-a",
      first_supplier_confirmation: confirmation_b
    )

    error = assert_raises(ActiveRecord::StatementInvalid) do
      SupplierIssuedIdentifier.transaction(requires_new: true) do
        SupplierIssuedIdentifier.insert_all!([ {
          id: SecureRandom.uuid_v7,
          agency_id: @agency.id,
          departure_id: @departure.id,
          supplier_arrangement_id: @arrangement.id,
          supplier_reservation_id: reservation_b.id,
          supplier_id: @supplier.id,
          issuer_context: "cruise line",
          identifier_type: "group_number",
          display_value: "OWN-B",
          normalized_value: "own-b",
          first_supplier_confirmation_id: confirmation_b.id,
          supersedes_id: prior_a.id,
          created_at: Time.current,
          updated_at: Time.current
        } ])
      end
    end
    assert_match(/ownership differs|already superseded|missing/i, error.message)
    assert_nil prior_a.reload.superseded_at
  end

  test "database rejects supersession that targets a different supplier under the arrangement" do
    other_supplier = create_capacity_supplier(@agency, "Other Identifier Supplier")
    error = assert_raises(ActiveRecord::StatementInvalid) do
      SupplierIssuedIdentifier.transaction(requires_new: true) do
        SupplierIssuedIdentifier.insert_all!([ {
          id: SecureRandom.uuid_v7,
          agency_id: @agency.id,
          departure_id: @departure.id,
          supplier_arrangement_id: @arrangement.id,
          supplier_id: other_supplier.id,
          issuer_context: "cruise line",
          identifier_type: "group_number",
          display_value: "GRP-OTHER",
          normalized_value: "grp-other",
          first_supplier_confirmation_id: @confirmation.id,
          supersedes_id: @prior.id,
          created_at: Time.current,
          updated_at: Time.current
        } ])
      end
    end
    assert_match(/ownership differs|already superseded|missing/i, error.message)
    assert_nil @prior.reload.superseded_at
  end

  test "supersession stamp permits only superseded_at mutation" do
    error = assert_raises(ActiveRecord::StatementInvalid) do
      SupplierIssuedIdentifier.transaction(requires_new: true) do
        SupplierIssuedIdentifier.connection.execute(<<~SQL.squish)
          UPDATE supplier_issued_identifiers
          SET superseded_at = CURRENT_TIMESTAMP,
              display_value = 'mutated'
          WHERE id = '#{@prior.id}'
        SQL
      end
    end
    assert_match(/append-only/i, error.message)
    assert_nil @prior.reload.superseded_at
    assert_equal "GRP-100", @prior.display_value
  end

  private

  def create_requested_reservation
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
    reservation
  end

  def respond_reservation(reservation)
    RecordSupplierReservationResponse.new(
      agency: @agency, actor: @actor, reservation: reservation,
      attributes: {
        channel: "portal",
        reference_note: "Confirmed",
        outcomes: reservation.revisions.where(status: "requested").sole.scopes.map { |scope|
          [ scope.id, { outcome_kind: "confirmed" } ]
        }.to_h,
        evidence: {
          evidence_kind: "supplier_confirmation",
          evidence_on: Date.current,
          channel: "portal",
          reference_note: "Confirmed",
          confirmed_without_identifier_reason: "Later"
        }
      },
      idempotency_key: SecureRandom.uuid
    ).call
  end
end
