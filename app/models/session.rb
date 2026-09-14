class Session < ApplicationRecord
  belongs_to :agency_user
  belongs_to :office, optional: true

  validates :credential_version, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def current?
    agency_user.active? &&
      agency_user.agency.active? &&
      credential_version == agency_user.credential_version
  end
end
