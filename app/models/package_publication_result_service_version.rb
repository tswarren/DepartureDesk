# frozen_string_literal: true

class PackagePublicationResultServiceVersion < ApplicationRecord
  belongs_to :agency
  belongs_to :package_publication_result
  belongs_to :service_offer_version

  attr_readonly :agency_id, :package_publication_result_id, :service_offer_version_id
end
