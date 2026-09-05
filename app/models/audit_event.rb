class AuditEvent < ApplicationRecord
  ACTIONS = %w[
    agency.profile_updated
    agency.provisioned
    agency.suspended
    agency.reactivated
    agency.closed
    team.invitation_created
    team.invitation_replaced
    team.invitation_revoked
    team.invitation_accepted
    team.role_changed
    team.membership_suspended
    team.membership_reactivated
    team.administrator_recovery_started
  ].freeze

  ACTOR_KINDS = %w[
    user
    system
  ].freeze

  belongs_to :agency
  belongs_to :actor_user, class_name: "User", optional: true

  enum :actor_kind, ACTOR_KINDS.index_by(&:itself), validate: true

  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :actor_user, presence: true, if: :user?
  validates :actor_identifier, presence: true, if: :system?
  validates :subject_type, presence: true, if: :subject_id?
  validates :subject_id, presence: true, if: :subject_type?

  before_destroy :reject_mutation
  before_update :reject_mutation

  private

  def reject_mutation
    errors.add(:base, "audit events are append-only")
    throw :abort
  end
end
