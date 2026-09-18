# frozen_string_literal: true

# Derived query: reservation_confirmation triggers covered by a confirmation's linked
# scopes on the current response link's Reservation/revision, still missing a commitment.
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
    seen = {}
    links.find_each do |link|
      confirmation = link.supplier_confirmation
      confirmed_scopes = SupplierReservationScope.where(
        id: SupplierConfirmationReservationScopeLink.where(
          supplier_confirmation_id: confirmation.id,
          supplier_reservation_id: link.supplier_reservation_id,
          supplier_reservation_revision_id: link.supplier_reservation_revision_id
        ).select(:supplier_reservation_scope_id)
      ).to_a
      next if confirmed_scopes.empty?

      link.supplier_arrangement_version.supplier_commitment_trigger_definitions
        .where(trigger_kind: "reservation_confirmation")
        .where(committed_supplier_id: confirmation.confirming_supplier_id)
        .find_each do |trigger|
        next unless confirmed_scopes.any? { |scope| trigger_matches_scope?(trigger, scope) }
        next if SupplierCommitment.exists?(
          supplier_confirmation_id: confirmation.id,
          supplier_commitment_trigger_definition_id: trigger.id
        )

        key = [
          confirmation.id,
          trigger.id,
          link.supplier_reservation_id,
          link.supplier_reservation_revision_id
        ]
        next if seen[key]

        seen[key] = true
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

  private

  def trigger_matches_scope?(trigger, scope)
    return true if trigger.arrangement_item_id.blank? && trigger.service_occurrence_id.blank? &&
      trigger.supplier_resource_id.blank? && trigger.capacity_pool_id.blank?

    (trigger.arrangement_item_id.blank? || trigger.arrangement_item_id == scope.arrangement_item_id) &&
      (trigger.service_occurrence_id.blank? || trigger.service_occurrence_id == scope.service_occurrence_id) &&
      (trigger.supplier_resource_id.blank? || trigger.supplier_resource_id == scope.supplier_resource_id) &&
      (trigger.capacity_pool_id.blank? || trigger.capacity_pool_id == scope.capacity_pool_id)
  end
end
