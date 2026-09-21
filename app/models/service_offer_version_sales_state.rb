# frozen_string_literal: true

class ServiceOfferVersionSalesState < ApplicationRecord
  belongs_to :agency
  belongs_to :departure
  belongs_to :service_offer_version

  attr_readonly :agency_id, :departure_id, :service_offer_version_id

  validates :sales_enabled, inclusion: { in: [ true, false ] }
end
