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
    departure.responsibility_changed
    departure.activated
    departure.returned_to_draft
    departure.departed
    departure.schedule_corrected
    departure.currency_corrected
    departure.lifecycle_corrected
    supplier_arrangement.created
    supplier_arrangement.updated
    supplier_arrangement.abandoned
    supplier_arrangement.item_created
    supplier_arrangement.item_updated
    supplier_arrangement.item_removed
    supplier_arrangement.items_reordered
    supplier_arrangement.occurrence_created
    supplier_arrangement.occurrence_updated
    supplier_arrangement.occurrence_removed
    supplier_arrangement.resource_created
    supplier_arrangement.resource_updated
    supplier_arrangement.resource_removed
    supplier_arrangement.resources_reordered
    supplier_arrangement.item_setup_created
    supplier_arrangement.typed_item_setup
    supplier_arrangement.capacity_applicability_updated
    supplier_arrangement.capacity_pair_classified
    supplier_arrangement.capacity_pairs_bulk_classified
    supplier_arrangement.capacity_pair_pool_configured
    supplier_arrangement.capacity_pair_removed
    supplier_arrangement.capacity_pool_created
    supplier_arrangement.capacity_pool_updated
    supplier_arrangement.capacity_pool_removed
    supplier_arrangement.capacity_pools_reordered
    supplier_arrangement.capacity_event_recorded
    supplier_arrangement.capacity_reconciled
    supplier_arrangement.capacity_reconciliation_resolved
    supplier_arrangement.cost_source_created
    supplier_arrangement.cost_setup_created
    supplier_arrangement.cost_source_updated
    supplier_arrangement.cost_source_removed
    supplier_arrangement.cost_sources_reordered
    supplier_arrangement.cost_definition_created
    supplier_arrangement.cost_definition_updated
    supplier_arrangement.cost_definition_removed
    supplier_arrangement.cost_definition_forecast_ready
    supplier_arrangement.cost_component_created
    supplier_arrangement.cost_component_updated
    supplier_arrangement.cost_component_removed
    supplier_arrangement.cost_components_reordered
    supplier_arrangement.cost_participant_category_created
    supplier_arrangement.cost_participant_category_updated
    supplier_arrangement.cost_participant_category_removed
    supplier_arrangement.cost_participant_categories_reordered
    supplier_arrangement.cost_usage_assumption_created
    supplier_arrangement.cost_usage_assumption_updated
    supplier_arrangement.cost_usage_assumption_removed
    supplier_arrangement.cost_occupancy_profile_created
    supplier_arrangement.cost_occupancy_profile_updated
    supplier_arrangement.cost_occupancy_profile_removed
    supplier_arrangement.cost_occupancy_profiles_reordered
    supplier_arrangement.activated
    supplier_arrangement.successor_created
    supplier_arrangement.successor_activated
    supplier_arrangement.identifier_superseded
    supplier_arrangement.commitment_trigger_created
    supplier_arrangement.commitment_trigger_updated
    supplier_arrangement.commitment_trigger_removed
    supplier_arrangement.deadline_definition_created
    supplier_arrangement.deadline_definition_updated
    supplier_arrangement.deadline_definition_removed
    supplier_arrangement.deadlines_materialized
    supplier_arrangement.deposit_definition_created
    supplier_arrangement.deposit_definition_updated
    supplier_arrangement.deposit_definition_removed
    supplier_arrangement.deposits_materialized
    supplier_arrangement.deposit_attested_external
    supplier_arrangement.planning_milestone_recorded
    supplier_arrangement.exposure_qualified
    supplier_arrangement.commitments_disposed
    supplier_arrangement.commitment_reopened
    supplier_arrangement.evidence_coverage_revoked
    supplier_arrangement.evidence_member_disqualified
    supplier_arrangement.ended
    supplier_reservation.created
    supplier_reservation.updated
    supplier_reservation.abandoned
    supplier_reservation.requested
    supplier_reservation.withdrawn
    supplier_reservation.response_recorded
    supplier_reservation.revised
    supplier_reservation.scopes_cancelled
    supplier_reservation.existing_confirmed_recorded
    service_offer.created
    service_offer.updated
    service_offer.fulfillment_basis_resolved
    service_offer.source_binding_added
    service_offer.source_binding_removed
    service_offer.discarded
    service_offer.price_created
    service_offer.price_updated
    service_offer.price_removed
    service_offer.cruise_client_terms_saved
    service_offer.published
    service_offer.successor_created
    service_offer.sales_paused
    service_offer.sales_resumed
    service_offer.retired
    package.created
    package.updated
    package.abandoned
    package.service_included
    package.service_adopted
    package.published_reusable_included
    package.inclusions_reordered
    package.inclusion_removed
    package.service_detached
    package.price_created
    package.price_updated
    package.price_removed
    package.terms_updated
    package.published
    package.successor_created
    package.sales_paused
    package.sales_resumed
    package.retired
    service_offer.choice_updated
    service_offer.cruise_connection_saved
    service_offer.terms_updated
  ].freeze

  ACTOR_KINDS = %w[agency_user system].freeze
  SUBJECT_TYPES = %w[Agency AgencyUser Office ClientPerson Client ClientOrganization Supplier SupplierLocation SupplierContact Departure SupplierArrangement SupplierReservation ServiceOffer Package].freeze

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
