# frozen_string_literal: true

class SupplierArrangementCruiseCapacityDepositRequirement < ApplicationRecord
  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :capacity_pool
  belongs_to :capacity_event

  validates :currency, format: { with: /\A[A-Z]{3}\z/ }
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :rate_minor_units, :amount_minor_units, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :amount_matches_quantity_times_rate

  private

  def amount_matches_quantity_times_rate
    return if quantity.blank? || rate_minor_units.blank? || amount_minor_units.blank?
    return if amount_minor_units == quantity * rate_minor_units

    errors.add(:amount_minor_units, "must equal quantity times rate")
  end
end
