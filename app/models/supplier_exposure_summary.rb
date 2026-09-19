# frozen_string_literal: true

class SupplierExposureSummary < ApplicationRecord
  QUALIFICATION_BANDS = SupplierExposureComponent::QUALIFICATION_BANDS
  COMPLETENESS_STATES = %w[known incomplete unknown partially_known].freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version

  enum :qualification_band, QUALIFICATION_BANDS.index_by(&:itself), validate: true
  enum :completeness, COMPLETENESS_STATES.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id

  monetize :gross_minor_units, as: :gross, with_model_currency: :currency, allow_nil: true
  monetize :expected_commission_minor_units, as: :expected_commission,
    with_model_currency: :currency, allow_nil: true
  monetize :expected_net_minor_units, as: :expected_net,
    with_model_currency: :currency, allow_nil: true
  monetize :required_deposit_minor_units, as: :required_deposit,
    with_model_currency: :currency, allow_nil: true

  validates :currency, :rebuilt_at, presence: true
end
