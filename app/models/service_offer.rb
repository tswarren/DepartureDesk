# frozen_string_literal: true

class ServiceOffer < ApplicationRecord
  NAME_LIMIT = 160

  belongs_to :agency
  belongs_to :departure

  has_many :versions, class_name: "ServiceOfferVersion", dependent: :restrict_with_exception
  has_many :definitions, class_name: "ServiceOfferDefinition", dependent: :restrict_with_exception
  has_many :source_bindings, class_name: "ServiceOfferSourceBinding", dependent: :restrict_with_exception
  has_many :price_definitions, class_name: "ServiceOfferPriceDefinition", dependent: :restrict_with_exception
  has_many :price_components, class_name: "ServiceOfferPriceComponent", dependent: :restrict_with_exception
  has_many :price_component_bases, class_name: "ServiceOfferPriceComponentBase", dependent: :restrict_with_exception
  has_many :package_inclusions, dependent: :restrict_with_exception

  attr_readonly :agency_id, :departure_id
  attr_accessor :client_title, :client_description, :fulfillment_basis, :refresh_bindings,
    :reselect_current_sources

  normalizes :name, with: ->(value) { value.to_s.strip }

  validates :name, presence: true, length: { maximum: NAME_LIMIT }

  def editable_draft_version
    versions.find_by(status: "draft")
  end
end
