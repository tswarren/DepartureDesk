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
    office.created
    office.updated
    office.deactivated
    office.reactivated
    office_access.granted
    office_access.revoked
    office_access.default_changed
    directory.party_created
    directory.party_updated
    directory.alternate_name_added
    directory.alternate_name_updated
    directory.alternate_name_removed
    directory.contact_created
    directory.contact_updated
    directory.contact_deactivated
    directory.contact_reactivated
    directory.contact_suppressed
    directory.contact_unsuppressed
    directory.contact_purpose_assigned
    directory.contact_purpose_ended
    directory.contact_purpose_corrected
    directory.relationship_created
    directory.relationship_ended
    directory.relationship_corrected
    directory.relationship_voided
    directory.relationship_purpose_assigned
    directory.relationship_purpose_ended
    directory.relationship_purpose_corrected
    directory.note_created
    directory.note_corrected
    directory.note_removed
    directory.note_pin_changed
    directory.client_profile_created
    directory.client_profile_updated
    directory.client_profile_deactivated
    directory.client_profile_reactivated
    directory.supplier_profile_created
    directory.supplier_profile_updated
    directory.supplier_profile_deactivated
    directory.supplier_profile_reactivated
    team.person_linked
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
