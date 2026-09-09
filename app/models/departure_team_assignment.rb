class DepartureTeamAssignment < ApplicationRecord
  ROLES = %w[
    group_manager
    responsible_advisor
  ].freeze

  belongs_to :agency
  belongs_to :departure, inverse_of: :team_assignments
  belongs_to :agency_membership
  belongs_to :assigned_by_membership, class_name: "AgencyMembership", inverse_of: false
  belongs_to :ended_by_membership, class_name: "AgencyMembership", optional: true, inverse_of: false

  enum :assignment_role, ROLES.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :agency_membership_id, :assignment_role, :effective_from, :assigned_by_membership_id

  normalizes :member_name_snapshot, with: ->(value) { value&.strip }
  normalizes :ending_reason, with: ->(value) { value&.strip.presence }

  validates :member_name_snapshot, :assigned_at, :effective_from, presence: true
  validate :range_order
  validate :lifecycle_complete
  validate :same_agency_participants

  scope :current, -> { where(effective_until: nil) }
  scope :current_on, ->(date) {
    where("effective_from <= ?", date)
      .where("effective_until IS NULL OR effective_until > ?", date)
  }

  def current?
    effective_until.nil?
  end

  def end!(ended_by:, reason:, ended_on:, ended_at: Time.current)
    assign_attributes(
      membership_status: nil,
      effective_until: ended_on,
      ended_at:,
      ended_by_membership: ended_by,
      ending_reason: reason
    )
    save!
  end

  private

  def range_order
    return if effective_from.blank? || effective_until.blank?
    return if effective_until >= effective_from

    errors.add(:effective_until, "must be on or after the start date")
  end

  def lifecycle_complete
    if current?
      unless membership_status == "active" && ended_at.blank? && ended_by_membership_id.blank? && ending_reason.blank?
        errors.add(:ending_reason, "must be blank while the assignment is current")
      end
    else
      unless membership_status.nil? && ended_at.present? && ended_by_membership_id.present? && ending_reason.present?
        errors.add(:ending_reason, "must be complete when the assignment has ended")
      end
    end
  end

  def same_agency_participants
    if departure.present? && agency_id.present? && departure.agency_id != agency_id
      errors.add(:departure, "must belong to the same agency")
    end
    if agency_membership.present? && agency_id.present? && agency_membership.agency_id != agency_id
      errors.add(:agency_membership, "must belong to the same agency")
    end
  end
end
