# frozen_string_literal: true

class SupplierExposureComponent < ApplicationRecord
  QUALIFICATION_BANDS = %w[guaranteed contingent forecast].freeze
  COMPLETENESS_STATES = %w[known incomplete unknown].freeze
  SOURCE_KINDS = %w[supplier_commitment supplier_cost_source].freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version

  enum :qualification_band, QUALIFICATION_BANDS.index_by(&:itself), validate: true
  enum :completeness, COMPLETENESS_STATES.index_by(&:itself), validate: true
  enum :source_kind, SOURCE_KINDS.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id

  monetize :gross_minor_units, as: :gross, with_model_currency: :currency, allow_nil: true
  monetize :expected_commission_minor_units, as: :expected_commission,
    with_model_currency: :currency, allow_nil: true
  monetize :expected_net_minor_units, as: :expected_net,
    with_model_currency: :currency, allow_nil: true

  validates :qualification_reason, :source_fingerprint, :currency, :effective_at, :rebuilt_at,
    presence: true
end
