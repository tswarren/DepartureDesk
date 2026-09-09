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
    directory.party_deactivated
    directory.party_reactivated
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
    directory.client_advisor_assigned
    directory.client_advisor_reassigned
    directory.client_advisor_cleared
    directory.supplier_profile_created
    directory.supplier_profile_updated
    directory.supplier_profile_deactivated
    directory.supplier_profile_reactivated
    directory.supplier_service_category_assigned
    directory.supplier_service_category_removed
    directory.external_identifier_created
    directory.external_identifier_deactivated
    directory.external_identifier_reactivated
    team.person_linked
    travel_program.created
    travel_program.updated
    travel_program.deactivated
    travel_program.reactivated
    departure.created
    departure.updated
    departure.planning_started
    departure.cancelled
    departure.office_transferred
    departure.team_member_assigned
    departure.team_member_replaced
    departure.team_assignment_ended
    departure.party_role_assigned
    departure.party_role_ended
    departure.party_role_primary_changed
    supplier_arrangement.created
    supplier_arrangement.updated
    supplier_arrangement.activated
    supplier_arrangement.cancelled
    supplier_arrangement.reparented
    supplier_reservation.created
    supplier_reservation.updated
    supplier_reservation.submitted
    supplier_reservation.confirmed
    supplier_reservation.cancelled
    supplier_resource.created
    supplier_resource.updated
    supplier_resource.deactivated
    supplier_service_occurrence.created
    supplier_confirmation.created
    supplier_confirmation.superseded
    supplier_cost_term.created
    supplier_cost_term.activated
    supplier_cost_term.superseded
    supplier_cost_term.voided
    supplier_commitment.opened
    supplier_commitment.released
    supplier_commitment.satisfied
    supplier_commitment.superseded
    supplier_commitment.cancelled
    supplier_deposit_requirement.created
    supplier_deposit_requirement.updated
    supplier_deposit_requirement.cancelled
    supplier_clause.created
    supplier_clause.updated
    supplier_clause.applied
    supplier_deadline.created
    supplier_deadline.rescheduled
    supplier_deadline.completed
    supplier_deadline.waived
    supplier_deadline.cancelled
    supplier_capacity_position.reconciled
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
