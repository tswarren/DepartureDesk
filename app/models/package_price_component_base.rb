# frozen_string_literal: true

class PackagePriceComponentBase < ApplicationRecord
  include DraftVersionDefinition
  guards_draft_version :package_version

  DIRECTIONS = %w[add subtract].freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :package
  belongs_to :package_version
  belongs_to :package_price_definition
  belongs_to :package_price_component
  belongs_to :base_component, class_name: "PackagePriceComponent"

  enum :direction, DIRECTIONS.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :package_id, :package_version_id,
    :package_price_definition_id, :package_price_component_id, :base_component_id

  validates :position, numericality: { only_integer: true, greater_than: 0 }
end
