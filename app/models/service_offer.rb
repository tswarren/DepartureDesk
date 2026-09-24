# frozen_string_literal: true

class ServiceOffer < ApplicationRecord
  NAME_LIMIT = 160

  belongs_to :agency
  belongs_to :departure
  belongs_to :intended_arrangement_item, class_name: "ArrangementItem", optional: true
  belongs_to :intended_supplier_arrangement, class_name: "SupplierArrangement", optional: true

  has_many :versions, class_name: "ServiceOfferVersion", dependent: :restrict_with_exception
  has_many :definitions, class_name: "ServiceOfferDefinition", dependent: :restrict_with_exception
  has_many :source_bindings, class_name: "ServiceOfferSourceBinding", dependent: :restrict_with_exception
  has_many :price_definitions, class_name: "ServiceOfferPriceDefinition", dependent: :restrict_with_exception
  has_many :price_components, class_name: "ServiceOfferPriceComponent", dependent: :restrict_with_exception
  has_many :price_component_bases, class_name: "ServiceOfferPriceComponentBase", dependent: :restrict_with_exception
  has_many :package_inclusions, dependent: :restrict_with_exception
  belongs_to :current_published_version, class_name: "ServiceOfferVersion", optional: true

  attr_readonly :agency_id, :departure_id
  attr_accessor :client_title, :client_description, :fulfillment_basis, :refresh_bindings,
    :reselect_current_sources

  normalizes :name, with: ->(value) { value.to_s.strip }

  validates :name, presence: true, length: { maximum: NAME_LIMIT }
  validate :intended_cruise_item_is_paired

  def editable_draft_version
    versions.find_by(status: "draft")
  end

  private

  def intended_cruise_item_is_paired
    item_present = intended_arrangement_item_id.present?
    arrangement_present = intended_supplier_arrangement_id.present?
    return if item_present == arrangement_present

    errors.add(:intended_arrangement_item, "must be paired with its cruise arrangement")
  end
end
