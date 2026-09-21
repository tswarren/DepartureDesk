# frozen_string_literal: true

class Package < ApplicationRecord
  NAME_LIMIT = 160

  belongs_to :agency
  belongs_to :departure

  has_many :versions, class_name: "PackageVersion", dependent: :restrict_with_exception
  has_many :inclusions, class_name: "PackageInclusion", dependent: :restrict_with_exception
  has_many :price_definitions, class_name: "PackagePriceDefinition", dependent: :restrict_with_exception

  attr_readonly :agency_id, :departure_id

  normalizes :name, with: ->(value) { value.to_s.strip }

  validates :name, presence: true, length: { maximum: NAME_LIMIT }

  def editable_draft_version
    versions.find_by(status: "draft")
  end
end
