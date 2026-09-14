class ClientOrganizationContact < ApplicationRecord
  belongs_to :agency
  belongs_to :client_organization
  belongs_to :client_person

  attr_readonly :agency_id, :client_organization_id, :client_person_id

  normalizes :title, :role_label, with: ->(value) { value.to_s.strip.presence }

  validate :historical_assignment_cannot_be_primary
  validate :ends_on_not_before_starts_on

  scope :current, -> { where(ends_on: nil) }
  scope :historical, -> { where.not(ends_on: nil) }
  scope :primary_first, -> { order(primary: :desc, starts_on: :desc, id: :asc) }

  def current?
    ends_on.nil?
  end

  private

  def historical_assignment_cannot_be_primary
    return unless primary? && ends_on.present?

    errors.add(:primary, "cannot be set on an ended assignment")
  end

  def ends_on_not_before_starts_on
    return if starts_on.blank? || ends_on.blank? || ends_on >= starts_on

    errors.add(:ends_on, "cannot be before the start date")
  end
end
