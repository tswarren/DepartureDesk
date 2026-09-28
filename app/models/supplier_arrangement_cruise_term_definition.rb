# frozen_string_literal: true

class SupplierArrangementCruiseTermDefinition < ApplicationRecord
  include ExactVersionCopyLineage
  include DraftVersionDefinition

  TERM_TYPES = %w[allocated_cabin_deposit card_restrictions cancellation_step].freeze
  TERM_LABELS = {
    "allocated_cabin_deposit" => "Allocated cabin deposit",
    "card_restrictions" => "Card restrictions",
    "cancellation_step" => "Cancellation terms"
  }.freeze
  RECORDED_LABEL = "Terms recorded; charges not calculated."
  BODY_LIMIT = 4_000

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version

  enum :term_type, TERM_TYPES.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :term_type

  normalizes :body, with: ->(value) { value.to_s.strip }

  validates :body, presence: true, length: { maximum: BODY_LIMIT }
  validates :position, numericality: { only_integer: true, greater_than: 0 }

  def self.label_for(term_type)
    TERM_LABELS.fetch(term_type.to_s)
  end
end
