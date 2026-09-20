# frozen_string_literal: true

class ServiceOfferPriceComponentBase < ApplicationRecord
  include DraftVersionDefinition
  guards_draft_version :service_offer_version

  DIRECTIONS = %w[add subtract].freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :service_offer
  belongs_to :service_offer_version
  belongs_to :service_offer_price_definition
  belongs_to :service_offer_price_component
  belongs_to :base_component, class_name: "ServiceOfferPriceComponent"

  enum :direction, DIRECTIONS.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :service_offer_id, :service_offer_version_id,
    :service_offer_price_definition_id, :service_offer_price_component_id, :base_component_id

  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validate :base_is_earlier_revenue_component

  private

  def base_is_earlier_revenue_component
    return if service_offer_price_component.nil? || base_component.nil?

    if service_offer_price_component_id == base_component_id
      errors.add(:base_component, "cannot reference itself")
    end
    if service_offer_price_component.service_offer_price_definition_id != base_component.service_offer_price_definition_id
      errors.add(:base_component, "must belong to the same price definition")
    end
    unless service_offer_price_component.percentage?
      errors.add(:base, "Only percentage price components accept bases")
    end
    if base_component.position.to_i >= service_offer_price_component.position.to_i
      errors.add(:base_component, "must be an earlier component in the same definition")
    end
    if base_component.included_tax_allocation?
      errors.add(:base_component, "an included-tax allocation cannot be a later percentage base")
    end
  end
end
