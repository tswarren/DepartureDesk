# frozen_string_literal: true

class PackageVersionSalesState < ApplicationRecord
  belongs_to :agency
  belongs_to :departure
  belongs_to :package_version

  attr_readonly :agency_id, :departure_id, :package_version_id

  validates :sales_enabled, inclusion: { in: [ true, false ] }
end
