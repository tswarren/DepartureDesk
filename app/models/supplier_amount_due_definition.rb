# frozen_string_literal: true

class SupplierAmountDueDefinition < ApplicationRecord
  include ExactVersionCopyLineage
  include DraftVersionDefinition
  include TransportationConfirmationFreeze::Model

  RULE_SHAPES = %w[fixed_date].freeze
  PRECISIONS = %w[date_only].freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version

  has_many :supplier_amount_due_contributors, dependent: :restrict_with_exception

  enum :rule_shape, RULE_SHAPES.index_by(&:itself), validate: true
  enum :precision, PRECISIONS.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id

  normalizes :currency, with: ->(value) { value.to_s.strip.upcase }
  normalizes :time_zone, with: ->(value) { value.to_s.strip }

  validates :currency, presence: true, format: { with: Agency::CURRENCY_FORMAT }
  validates :time_zone, :rule_parameters, presence: true
  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validate :date_parameter_is_present

  private

  def date_parameter_is_present
    date = rule_parameters.is_a?(Hash) ? rule_parameters["date"] || rule_parameters[:date] : nil
    errors.add(:rule_parameters, "must include a date") if date.blank?
  end
end
