class ClientPerson < ApplicationRecord
  STATUSES = %w[active inactive].freeze

  belongs_to :agency
  has_one :client, dependent: :restrict_with_exception
  has_many :email_addresses, class_name: "ClientPersonEmailAddress", dependent: :restrict_with_exception
  has_many :phone_numbers, class_name: "ClientPersonPhoneNumber", dependent: :restrict_with_exception
  has_many :postal_addresses, class_name: "ClientPersonPostalAddress", dependent: :restrict_with_exception
  has_many :organization_contacts, class_name: "ClientOrganizationContact", dependent: :restrict_with_exception

  enum :status, STATUSES.index_by(&:itself), validate: true, default: "active"

  attr_readonly :agency_id

  normalizes :first_name, :middle_name, :last_name, :suffix, :preferred_name, with: ->(value) { value.to_s.strip.presence }

  validates :first_name, :last_name, presence: true

  def display_name
    [ preferred_name.presence || first_name, last_name ].compact.join(" ")
  end

  def full_name
    [ first_name, middle_name, last_name, suffix ].compact_blank.join(" ")
  end
end
