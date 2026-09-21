# frozen_string_literal: true

class PackageClientStatedCondition < ApplicationRecord
  include DraftVersionDefinition
  guards_draft_version :package_version

  KINDS = %w[eligibility acknowledgment].freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :package
  belongs_to :package_version

  enum :condition_kind, KINDS.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :package_id, :package_version_id

  normalizes :body, with: ->(value) { value.to_s.strip }
  validates :body, presence: true, length: { maximum: 2_000 }
end
