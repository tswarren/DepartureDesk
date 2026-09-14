class Client < ApplicationRecord
  STATUSES = %w[active inactive].freeze
  REFERENCE_FORMAT = /\ACL-[0-9]{6}\z/

  belongs_to :agency
  belongs_to :client_person

  enum :status, STATUSES.index_by(&:itself), validate: true, default: "active"

  attr_readonly :agency_id, :client_person_id, :client_reference

  validates :client_reference, presence: true, format: { with: REFERENCE_FORMAT }
  validates :client_person_id, uniqueness: true
end
