class ClientProfile < ApplicationRecord
  include RoleProfile

  PARTY_KINDS = Party::KINDS
  COMMUNICATION_PREFERENCES = %w[
    no_preference
    email
    phone
    postal_mail
  ].freeze
  RESTRICTION_LIMIT = 2000

  belongs_to :primary_advisor_membership,
    class_name: "AgencyMembership",
    optional: true,
    inverse_of: false
  has_many :advisor_assignments,
    class_name: "ClientAdvisorAssignment",
    inverse_of: :client_profile,
    dependent: :restrict_with_exception
  has_many :external_identifiers,
    inverse_of: :client_profile,
    dependent: :restrict_with_exception

  enum :communication_preference, COMMUNICATION_PREFERENCES.index_by(&:itself), validate: true

  normalizes :servicing_restrictions, :billing_restrictions, with: ->(value) { value&.strip.presence }

  validates :party_kind, inclusion: { in: PARTY_KINDS }
  validates :servicing_restrictions, :billing_restrictions, length: { maximum: RESTRICTION_LIMIT }
  validate :advisor_projection_matches_status
  validate :restriction_content

  def open_advisor_assignment
    advisor_assignments.open.order(:effective_from, :id).first
  end

  private

  def advisor_projection_matches_status
    if inactive?
      errors.add(:primary_advisor_membership_id, "must be blank") if primary_advisor_membership_id.present?
      errors.add(:primary_advisor_membership_status, "must be blank") if primary_advisor_membership_status.present?
      return
    end

    if primary_advisor_membership_id.blank?
      errors.add(:primary_advisor_membership_status, "must be blank") if primary_advisor_membership_status.present?
      return
    end

    errors.add(:primary_advisor_membership_status, "must be active") unless primary_advisor_membership_status == "active"
    if primary_advisor_membership.present? && !primary_advisor_membership.active?
      errors.add(:primary_advisor_membership, "must be active")
    end
    if primary_advisor_membership.present? && agency_id.present? && primary_advisor_membership.agency_id != agency_id
      errors.add(:primary_advisor_membership, "must belong to the same agency")
    end
  end

  def restriction_content
    %i[servicing_restrictions billing_restrictions].each do |attribute|
      value = public_send(attribute)
      next if value.blank?

      violation = PartyNoteContentPolicy.violation_for(value)
      errors.add(attribute, violation) if violation
    end
  end
end
