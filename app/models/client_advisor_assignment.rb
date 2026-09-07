class ClientAdvisorAssignment < ApplicationRecord
  belongs_to :agency
  belongs_to :client_profile, inverse_of: :advisor_assignments
  belongs_to :advisor_membership, class_name: "AgencyMembership", inverse_of: false
  belongs_to :ended_by_membership, class_name: "AgencyMembership", optional: true, inverse_of: false

  attr_readonly :agency_id, :client_profile_id, :advisor_membership_id, :effective_from

  normalizes :ending_reason, with: ->(value) { value&.strip.presence }

  validate :range_order
  validate :ending_complete
  validate :same_agency_participants

  scope :open, -> { where(effective_until: nil) }
  scope :current_on, ->(date) {
    where("effective_from <= ?", date)
      .where("effective_until IS NULL OR effective_until > ?", date)
  }

  def open?
    effective_until.nil?
  end

  private

  def range_order
    return if effective_from.blank? || effective_until.blank?
    return if effective_until >= effective_from

    errors.add(:effective_until, "must be on or after the start date")
  end

  def ending_complete
    ended = ended_at.present? || ended_by_membership_id.present? || ending_reason.present? || effective_until.present?
    complete = ended_at.present? && ended_by_membership_id.present? && ending_reason.present? && effective_until.present?
    open_row = ended_at.blank? && ended_by_membership_id.blank? && ending_reason.blank? && effective_until.blank?
    return if complete || open_row
    return unless ended

    errors.add(:ending_reason, "must be complete with an end date")
  end

  def same_agency_participants
    if client_profile.present? && agency_id.present? && client_profile.agency_id != agency_id
      errors.add(:client_profile, "must belong to the same agency")
    end
    if advisor_membership.present? && agency_id.present? && advisor_membership.agency_id != agency_id
      errors.add(:advisor_membership, "must belong to the same agency")
    end
  end
end
