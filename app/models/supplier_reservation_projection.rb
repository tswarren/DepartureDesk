class SupplierReservationProjection < ApplicationRecord
  STATES = %w[
    planned requested partially_confirmed confirmed declined withdrawn cancelled
  ].freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_reservation
  belongs_to :current_revision, class_name: "SupplierReservationRevision", optional: true

  enum :state, STATES.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id, :supplier_reservation_id

  validates :planned_scope_count, :pending_scope_count, :confirmed_scope_count,
    :counterproposed_scope_count, :declined_scope_count, :withdrawn_scope_count,
    :cancelled_scope_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :rebuilt_at, presence: true
end
