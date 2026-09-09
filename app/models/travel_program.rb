class TravelProgram < ApplicationRecord
  STATUSES = %w[
    active
    inactive
  ].freeze

  belongs_to :agency
  belongs_to :inactivated_by_membership,
    class_name: "AgencyMembership",
    optional: true,
    inverse_of: false
  has_many :departures, dependent: :restrict_with_exception

  enum :status, STATUSES.index_by(&:itself), validate: true

  attr_readonly :agency_id

  normalizes :name, with: ->(value) { value&.strip }
  normalizes :description, :client_facing_description, :inactivation_reason, with: ->(value) { value&.strip.presence }

  validates :name, presence: true
  validate :lifecycle_matches_status

  def nonterminal_departures
    departures.nonterminal
  end

  private

  def lifecycle_matches_status
    if active?
      if inactivated_at.present? || inactivated_by_membership_id.present? || inactivation_reason.present?
        errors.add(:status, "cannot keep inactivation metadata while active")
      end
    elsif inactive?
      if inactivated_at.blank? || inactivated_by_membership_id.blank? || inactivation_reason.blank?
        errors.add(:inactivation_reason, "must be complete while inactive")
      end
    end
  end
end
