module RoleProfile
  extend ActiveSupport::Concern

  STATUSES = %w[
    active
    inactive
  ].freeze

  included do
    belongs_to :agency
    belongs_to :party, inverse_of: name.underscore.to_sym
    belongs_to :responsible_office, class_name: "Office", inverse_of: false
    belongs_to :deactivated_by_membership,
      class_name: "AgencyMembership",
      optional: true,
      inverse_of: false

    enum :status, STATUSES.index_by(&:itself), validate: true

    attr_readonly :agency_id, :party_id, :party_kind

    normalizes :deactivation_reason, with: ->(value) { value&.strip.presence }

    validates :party_kind, presence: true
    validate :deactivation_matches_status
    validate :office_projection_matches_status
    validate :actors_and_office_same_agency
    validate :party_kind_matches_party
  end

  def role_label
    self.class.model_name.human
  end

  private

  def deactivation_matches_status
    if active?
      errors.add(:deactivated_at, "must be blank") if deactivated_at.present?
      errors.add(:deactivated_by_membership_id, "must be blank") if deactivated_by_membership_id.present?
      errors.add(:deactivation_reason, "must be blank") if deactivation_reason.present?
    elsif inactive?
      errors.add(:deactivated_at, "must be present") if deactivated_at.blank?
      errors.add(:deactivated_by_membership_id, "must be present") if deactivated_by_membership_id.blank?
      errors.add(:deactivation_reason, "must be present") if deactivation_reason.blank?
    end
  end

  def office_projection_matches_status
    if active?
      errors.add(:responsible_office_status, "must be active") unless responsible_office_status == "active"
    elsif inactive?
      errors.add(:responsible_office_status, "must be blank") if responsible_office_status.present?
    end
  end

  def actors_and_office_same_agency
    if responsible_office.present? && agency_id.present? && responsible_office.agency_id != agency_id
      errors.add(:responsible_office, "must belong to the same agency")
    end
    if deactivated_by_membership.present? && agency_id.present? && deactivated_by_membership.agency_id != agency_id
      errors.add(:deactivated_by_membership, "must belong to the same agency")
    end
  end

  def party_kind_matches_party
    return if party.blank? || party_kind.blank?
    return if party.party_kind == party_kind

    errors.add(:party_kind, "must match the party")
  end
end
