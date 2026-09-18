# frozen_string_literal: true

require "ostruct"

# Derived query: reservation_confirmation triggers with a confirmation but no commitment.
class UnresolvedReservationCommitmentTriggers
  Result = Data.define(:confirmation, :trigger, :reservation, :revision)

  def self.call(agency:, reservation: nil, confirmation: nil)
    new(agency:, reservation:, confirmation:).call
  end

  def initialize(agency:, reservation: nil, confirmation: nil)
    @agency = agency
    @reservation = reservation
    @confirmation = confirmation
  end

  def call
    links = SupplierConfirmationReservationResponseLink
      .where(agency_id: @agency.id)
      .includes(
        :supplier_confirmation,
        :supplier_reservation,
        :supplier_reservation_revision,
        supplier_arrangement_version: :supplier_commitment_trigger_definitions
      )
    links = links.where(supplier_reservation_id: @reservation.id) if @reservation
    links = links.where(supplier_confirmation_id: @confirmation.id) if @confirmation

    results = []
    links.find_each do |link|
      version = link.supplier_arrangement_version
      confirmation = link.supplier_confirmation
      version.supplier_commitment_trigger_definitions
        .where(trigger_kind: "reservation_confirmation")
        .where(committed_supplier_id: confirmation.confirming_supplier_id)
        .find_each do |trigger|
        next if SupplierCommitment.exists?(
          supplier_confirmation_id: confirmation.id,
          supplier_commitment_trigger_definition_id: trigger.id
        )

        results << Result.new(
          confirmation: confirmation,
          trigger: trigger,
          reservation: link.supplier_reservation,
          revision: link.supplier_reservation_revision
        )
      end
    end
    results
  end
end
