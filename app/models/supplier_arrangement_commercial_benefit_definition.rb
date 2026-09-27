# frozen_string_literal: true

class SupplierArrangementCommercialBenefitDefinition < ApplicationRecord
  include ExactVersionCopyLineage
  include DraftVersionDefinition

  TERM_TYPES = %w[tour_conductor_credit group_amenity_program].freeze
  TERM_LABELS = {
    "tour_conductor_credit" => "Tour-conductor credit",
    "group_amenity_program" => "Group Amenity Program"
  }.freeze
  BODY_LIMIT = 4_000
  CITATION_LIMIT = 160
  RECORDED_LABEL = "Terms recorded; entitlement not calculated."

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :supplier_arrangement_commercial_benefit

  enum :term_type, TERM_TYPES.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :supplier_arrangement_commercial_benefit_id,
    :term_type

  normalizes :body, with: ->(value) { value.to_s.strip }
  normalizes :source_citation, with: ->(value) { value.to_s.strip.presence }

  validates :body, presence: true, length: { maximum: BODY_LIMIT }
  validates :source_citation, length: { maximum: CITATION_LIMIT }, allow_nil: true
  validates :term_type, uniqueness: { scope: :supplier_arrangement_version_id }

  def self.label_for(term_type)
    TERM_LABELS.fetch(term_type.to_s)
  end

  def label
    self.class.label_for(term_type)
  end
end
