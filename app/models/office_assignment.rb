class OfficeAssignment < ApplicationRecord
  STATUSES = %w[
    active
    revoked
  ].freeze

  belongs_to :agency
  belongs_to :agency_membership
  belongs_to :office

  enum :status, STATUSES.index_by(&:itself), validate: true

  validates :granted_at, presence: true
  validates :office_id, uniqueness: { scope: :agency_membership_id }
  validates :is_default, inclusion: { in: [ true, false ] }
  validate :default_requires_active_status
  validate :revoked_at_matches_status
  validate :same_agency_as_membership_and_office

  def revoke!(at: Time.current)
    update!(status: "revoked", is_default: false, revoked_at: at)
  end

  def regrant!(make_default: false, at: Time.current)
    update!(
      status: "active",
      is_default: make_default,
      granted_at: at,
      revoked_at: nil
    )
  end

  private

  def default_requires_active_status
    return unless is_default? && !active?

    errors.add(:is_default, "can only be set on an active assignment")
  end

  def revoked_at_matches_status
    if revoked? && revoked_at.blank?
      errors.add(:revoked_at, "is required when revoked")
    elsif active? && revoked_at.present?
      errors.add(:revoked_at, "must be blank when active")
    end
  end

  def same_agency_as_membership_and_office
    if agency_membership && agency_id != agency_membership.agency_id
      errors.add(:agency_membership, "must belong to the same agency")
    end
    if office && agency_id != office.agency_id
      errors.add(:office, "must belong to the same agency")
    end
  end
end
