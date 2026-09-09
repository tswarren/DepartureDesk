class DeparturePartyRoleAssignment < ApplicationRecord
  ROLES = %w[
    organizer
    group_leader
    sponsor
  ].freeze

  belongs_to :agency
  belongs_to :departure, inverse_of: :party_role_assignments
  belongs_to :party
  belongs_to :assigned_by_membership, class_name: "AgencyMembership", inverse_of: false
  belongs_to :ended_by_membership, class_name: "AgencyMembership", optional: true, inverse_of: false

  enum :role, ROLES.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :party_id, :party_kind, :role, :effective_from, :assigned_by_membership_id

  normalizes :party_display_name_snapshot, with: ->(value) { value&.strip }
  normalizes :ending_reason, with: ->(value) { value&.strip.presence }

  validates :party_display_name_snapshot, :assigned_at, :effective_from, :party_kind, presence: true
  validate :group_leader_is_person
  validate :range_order
  validate :lifecycle_complete
  validate :same_agency_participants

  scope :current, -> { where(effective_until: nil) }
  scope :current_on, ->(date) {
    where("effective_from <= ?", date)
      .where("effective_until IS NULL OR effective_until > ?", date)
  }
  scope :primary, -> { where(is_primary: true) }

  def current?
    effective_until.nil?
  end

  def end!(ended_by:, reason:, ended_on:, ended_at: Time.current)
    assign_attributes(
      is_primary: false,
      effective_until: ended_on,
      ended_at:,
      ended_by_membership: ended_by,
      ending_reason: reason
    )
    save!
  end

  private

  def group_leader_is_person
    return unless group_leader?
    return if party_kind == "person"

    errors.add(:party, "must be a person to be a group leader")
  end

  def range_order
    return if effective_from.blank? || effective_until.blank?
    return if effective_until >= effective_from

    errors.add(:effective_until, "must be on or after the start date")
  end

  def lifecycle_complete
    if current?
      if ended_at.present? || ended_by_membership_id.present? || ending_reason.present?
        errors.add(:ending_reason, "must be blank while the assignment is current")
      end
    else
      unless ended_at.present? && ended_by_membership_id.present? && ending_reason.present?
        errors.add(:ending_reason, "must be complete when the assignment has ended")
      end
    end
  end

  def same_agency_participants
    if departure.present? && agency_id.present? && departure.agency_id != agency_id
      errors.add(:departure, "must belong to the same agency")
    end
    if party.present? && agency_id.present? && party.agency_id != agency_id
      errors.add(:party, "must belong to the same agency")
    end
  end
end
