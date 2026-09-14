class AuditEvent < ApplicationRecord
  ACTIONS = %w[
    agency.provisioned
    agency.profile_updated
    agency.suspended
    agency.reactivated
    agency.closed
    office.created
    office.updated
    office.deactivated
    office.reactivated
    agency_user.invited
    agency_user.invitation_replaced
    agency_user.invitation_revoked
    agency_user.invitation_accepted
    agency_user.role_changed
    agency_user.updated
    agency_user.suspended
    agency_user.reactivated
    agency_user.closed
    agency_user.default_office_changed
    agency_user.password_changed
    agency_user.password_reset
    session.office_selected
  ].freeze

  ACTOR_KINDS = %w[agency_user system].freeze
  SUBJECT_TYPES = %w[Agency AgencyUser Office].freeze

  belongs_to :agency
  belongs_to :actor_agency_user, class_name: "AgencyUser", optional: true

  enum :actor_kind, ACTOR_KINDS.index_by(&:itself), validate: true

  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :actor_agency_user, presence: true, if: :agency_user?
  validates :actor_identifier, presence: true, if: :system?
  validates :subject_type, inclusion: { in: SUBJECT_TYPES }, allow_nil: true

  before_update :reject_mutation
  before_destroy :reject_mutation

  private

  def reject_mutation
    errors.add(:base, "audit events are append-only")
    throw :abort
  end
end
