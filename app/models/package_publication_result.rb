# frozen_string_literal: true

class PackagePublicationResult < ApplicationRecord
  belongs_to :agency
  belongs_to :departure
  belongs_to :agency_command_idempotency_key
  belongs_to :package_version
  has_many :service_versions, class_name: "PackagePublicationResultServiceVersion",
    dependent: :restrict_with_exception

  attr_readonly :agency_id, :departure_id, :agency_command_idempotency_key_id, :package_version_id

  validates :agency_command_idempotency_key_id, uniqueness: true
end
