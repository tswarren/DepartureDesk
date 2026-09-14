class Client < ApplicationRecord
  STATUSES = %w[active inactive].freeze
  REFERENCE_FORMAT = /\ACL-[0-9]{6}\z/

  belongs_to :agency
  belongs_to :client_person, optional: true
  belongs_to :client_organization, optional: true

  enum :status, STATUSES.index_by(&:itself), validate: true, default: "active"

  attr_readonly :agency_id, :client_person_id, :client_organization_id, :client_reference

  validates :client_reference, presence: true, format: { with: REFERENCE_FORMAT }
  validates :client_person_id, uniqueness: true, allow_nil: true
  validates :client_organization_id, uniqueness: true, allow_nil: true
  validate :exactly_one_source

  def source
    client_person || client_organization
  end

  private

  def exactly_one_source
    sources = [ client_person_id, client_organization_id ].compact
    return if sources.size == 1

    errors.add(:base, "Client must belong to exactly one Person or Organization")
  end
end
