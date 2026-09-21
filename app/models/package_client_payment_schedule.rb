# frozen_string_literal: true

class PackageClientPaymentSchedule < ApplicationRecord
  include DraftVersionDefinition
  guards_draft_version :package_version

  belongs_to :agency
  belongs_to :departure
  belongs_to :package
  belongs_to :package_version
  has_many :lines, class_name: "PackageClientPaymentScheduleLine", dependent: :restrict_with_exception

  attr_readonly :agency_id, :departure_id, :package_id, :package_version_id
end
