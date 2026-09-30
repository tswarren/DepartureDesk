# frozen_string_literal: true

class SupplierDepositBasis < ApplicationRecord
  include ExactVersionCopyLineage
  include DraftVersionDefinition

  BASIS_KINDS = %w[original_contracted_room_revenue].freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :arrangement_item

  has_many :supplier_deposit_basis_entries, dependent: :restrict_with_exception
  has_many :supplier_deposit_basis_shares, dependent: :restrict_with_exception

  enum :basis_kind, BASIS_KINDS.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :arrangement_item_id, :basis_kind

  normalizes :currency, with: ->(value) { value.to_s.strip.upcase }

  validates :currency, presence: true, format: { with: Agency::CURRENCY_FORMAT }
  validates :basis_amount_minor_units, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :arrangement_item_id, uniqueness: { scope: :supplier_arrangement_version_id }
  validate :currency_matches_departure

  private

  def currency_matches_departure
    return if currency.blank? || departure.nil?
    return if currency == departure.operating_currency

    errors.add(:currency, "must equal the departure operating currency")
  end
end
