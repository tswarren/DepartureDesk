class ClientOrganizationContact < ApplicationRecord
  belongs_to :agency
  belongs_to :client_organization
  belongs_to :client_person

  attr_readonly :agency_id, :client_organization_id, :client_person_id

  normalizes :title, :role_label, with: ->(value) { value.to_s.strip.presence }

  scope :current, -> { where(ends_on: nil) }
  scope :historical, -> { where.not(ends_on: nil) }
  scope :primary_first, -> { order(primary: :desc, starts_on: :desc, id: :asc) }

  def current?
    ends_on.nil?
  end
end
