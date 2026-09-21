# frozen_string_literal: true

class PackagePriceComponent < ApplicationRecord
  include DraftVersionDefinition
  guards_draft_version :package_version

  CLIENT_ROLES = %w[base_price named_discount named_surcharge tax_fee].freeze
  CALCULATION_KINDS = %w[fixed unit_rate percentage].freeze
  QUANTITY_BASES = %w[service_instances persons].freeze
  PERCENTAGE_TREATMENTS = %w[additive included].freeze
  LABEL_LIMIT = 160

  belongs_to :agency
  belongs_to :departure
  belongs_to :package
  belongs_to :package_version
  belongs_to :package_price_definition
  has_many :package_price_component_bases, class_name: "PackagePriceComponentBase", dependent: :restrict_with_exception
  has_many :dependent_base_links, class_name: "PackagePriceComponentBase",
    foreign_key: :base_component_id, inverse_of: :base_component, dependent: :restrict_with_exception

  enum :client_role, CLIENT_ROLES.index_by(&:itself), validate: true
  enum :calculation_kind, CALCULATION_KINDS.index_by(&:itself), validate: true
  enum :quantity_basis, QUANTITY_BASES.index_by(&:itself), validate: { allow_nil: true }
  enum :percentage_treatment, PERCENTAGE_TREATMENTS.index_by(&:itself), validate: { allow_nil: true }

  attr_readonly :agency_id, :departure_id, :package_id, :package_version_id, :package_price_definition_id

  normalizes :label, with: ->(value) { value.to_s.strip }

  validates :label, presence: true, length: { maximum: LABEL_LIMIT }
  validates :position, numericality: { only_integer: true, greater_than: 0 }
end
