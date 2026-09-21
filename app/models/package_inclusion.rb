# frozen_string_literal: true

class PackageInclusion < ApplicationRecord
  include DraftVersionDefinition
  guards_draft_version :package_version

  PLACEMENTS = %w[included optional].freeze
  ORIGINS = %w[inline_create adopted_draft published_reusable].freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :package
  belongs_to :package_version
  belongs_to :service_offer
  belongs_to :service_offer_version

  enum :placement, PLACEMENTS.index_by(&:itself), validate: true, default: "included"
  enum :origin, ORIGINS.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :package_id, :package_version_id,
    :service_offer_id, :service_offer_version_id

  validates :position, numericality: { only_integer: true, greater_than: 0 }
end
