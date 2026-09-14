class ClientOrganization < ApplicationRecord
  STATUSES = %w[active inactive].freeze

  belongs_to :agency
  has_one :client, dependent: :restrict_with_exception
  has_many :email_addresses, class_name: "ClientOrganizationEmailAddress", dependent: :restrict_with_exception
  has_many :phone_numbers, class_name: "ClientOrganizationPhoneNumber", dependent: :restrict_with_exception
  has_many :postal_addresses, class_name: "ClientOrganizationPostalAddress", dependent: :restrict_with_exception
  has_many :websites, class_name: "ClientOrganizationWebsite", dependent: :restrict_with_exception
  has_many :organization_contacts, class_name: "ClientOrganizationContact", dependent: :restrict_with_exception

  enum :status, STATUSES.index_by(&:itself), validate: true, default: "active"

  attr_readonly :agency_id

  normalizes :display_name, with: ->(value) { value.to_s.strip }
  normalizes :legal_name, with: ->(value) { value.to_s.strip.presence }

  validates :display_name, presence: true

  def display_name_for_directory
    display_name
  end
end
