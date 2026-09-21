# frozen_string_literal: true

class PackageClientTermResolution < ApplicationRecord
  include DraftVersionDefinition
  guards_draft_version :package_version

  KINDS = %w[payment cancellation stated_condition].freeze
  SIDES = %w[package service].freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :package
  belongs_to :package_version
  belongs_to :service_offer_version

  enum :kind, KINDS.index_by(&:itself), validate: true
  enum :governing_side, SIDES.index_by(&:itself), validate: true, prefix: :governed_by

  attr_readonly :agency_id, :departure_id, :package_id, :package_version_id

  normalizes :reason, with: ->(value) { value.to_s.strip }
  validates :reason, presence: true, length: { maximum: 500 }
end
