class AuditEvent < ApplicationRecord
  ACTIONS = %w[
    agency.provisioned
    agency.profile_updated
    agency.logo_updated
    agency.logo_removed
    agency.suspended
    agency.reactivated
    agency.closed
    office.created
    office.updated
    office.deactivated
    office.reactivated
    traveler_type.created
    traveler_type.updated
    agency_user.invited
    agency_user.invitation_replaced
    agency_user.invitation_revoked
    agency_user.invitation_accepted
    agency_user.type_changed
    agency_user.permissions_changed
    agency_user.updated
    agency_user.suspended
    agency_user.reactivated
    agency_user.closed
    agency_user.default_office_changed
    agency_user.password_changed
    agency_user.password_reset
    session.office_selected
    client_person.created
    client_person.updated
    client_person.inactivated
    client_person.reactivated
    client_person.contact_updated
    client_person.duplicate_override
    client.created
    client.inactivated
    client.reactivated
    client_organization.created
    client_organization.updated
    client_organization.contact_updated
    client_organization.contact_added
    client_organization.contact_ended
    client_organization.primary_contact_changed
    client_organization.inactivated
    client_organization.reactivated
    client_organization.duplicate_override
    supplier.created
    supplier.updated
    supplier.categories_changed
    supplier.contact_updated
    supplier.inactivated
    supplier.reactivated
    supplier.duplicate_override
    supplier.payee_account_added
    supplier.payee_account_updated
    supplier_location.created
    supplier_location.updated
    supplier_location.inactivated
    supplier_location.reactivated
    supplier_location.duplicate_override
    supplier_contact.created
    supplier_contact.updated
    supplier_contact.contact_updated
    supplier_contact.preferred_changed
    supplier_contact.inactivated
    supplier_contact.reactivated
    supplier_contact.duplicate_override
    departure.created
    departure.updated
    departure.decision_recorded
    supplier_arrangement.created
    supplier_arrangement.updated
    supplier_arrangement.discarded
    supplier_arrangement.confirmed
    supplier_arrangement.document_added
    supplier_arrangement.document_removed
    supplier_arrangement.inventory_group_added
    supplier_arrangement.inventory_group_updated
    supplier_arrangement.inventory_group_removed
    supplier_arrangement.capacity_rule_changed
    supplier_arrangement.capacity_changed
    departure.team_member_added
    departure.team_member_removed
    departure.default_task_owner_changed
    departure.ready_to_sell
    departure.returned_to_draft
    departure.departed
  ].freeze

  ACTOR_KINDS = %w[agency_user system].freeze
  SUBJECT_TYPES = %w[Agency AgencyUser Office ClientPerson Client ClientOrganization Supplier SupplierLocation SupplierContact Departure TravelerType SupplierArrangement].freeze

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
