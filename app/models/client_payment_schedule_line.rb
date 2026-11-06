# One line of a Departure's client payment schedule template (CMN-09,
# D-76, D-77): a fixed amount per traveler, per unit of a named service
# category or per booking, a percentage, or the balance; due at
# confirmation, a number of days before departure, or on a date. One line
# may be the designated payment that counts as acceptance (BKG-41).
# Installments are proposed from it in step 6.
class ClientPaymentScheduleLine < ApplicationRecord
  BASES = %w[per_traveler per_unit per_booking percentage balance].freeze
  DUE_RULES = %w[at_confirmation days_before_departure fixed_date].freeze

  belongs_to :agency
  belongs_to :client_terms_version

  enum :basis, BASES.index_by(&:itself), validate: true, prefix: :basis
  enum :due_rule, DUE_RULES.index_by(&:itself), validate: true, prefix: :due

  attr_readonly :agency_id, :client_terms_version_id

  normalizes :description, with: ->(value) { value.to_s.squish }

  validates :description, presence: true, length: { maximum: 120 }
  validates :service_category, inclusion: { in: InventoryGroup::SERVICE_CATEGORIES }, if: :basis_per_unit?

  scope :ordered, -> { order(:position, :created_at) }
end
