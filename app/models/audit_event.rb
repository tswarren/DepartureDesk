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
    reseller.authorized
    reseller.updated
    session.office_selected
    client_person.created
    client_person.updated
    client_person.inactivated
    client_person.reactivated
    client_person.contact_updated
    client_person.duplicate_override
    client.created
    client.traveler_linked
    client.traveler_unlinked
    traveler.created
    traveler.updated
    client_trip.created
    client_trip.updated
    client_booking.created
    client_booking.traveler_added
    client_booking.traveler_updated
    client_booking.traveler_removed
    client_booking.selection_added
    client_booking.selection_updated
    client_booking.selection_removed
    client_booking.space_held
    client_booking.hold_extended
    client_booking.hold_released
    client_booking.discarded
    client_booking.acceptance_recorded
    client_booking.confirmed
    client_booking.assigned
    client_booking.seller_of_record_set
    client_booking.supplier_cost_overridden
    client_booking.installments_created
    client_booking.installments_adjusted
    client_payment.recorded
    client_payment.applied
    client_payment.reversed
    supplier_payment.recorded
    supplier_payment.applied
    supplier_payment.reversed
    client_booking.commission_confirmed
    supplier_reservation.requested
    supplier_reservation.confirmed
    departure.client_terms_locked
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
    supplier_arrangement.rate_line_added
    supplier_arrangement.rates_saved
    supplier_arrangement.rates_copied
    supplier_arrangement.rate_pattern_set
    supplier_arrangement.rate_band_added
    supplier_arrangement.rate_band_removed
    supplier_arrangement.rate_line_updated
    supplier_arrangement.rate_line_removed
    supplier_arrangement.deadline_recorded
    supplier_arrangement.deadline_updated
    supplier_arrangement.cost_line_added
    supplier_arrangement.cost_line_updated
    supplier_arrangement.cost_line_removed
    supplier_arrangement.schedule_line_added
    supplier_arrangement.schedule_line_updated
    supplier_arrangement.trigger_event_recorded
    supplier_arrangement.amounts_due_posted
    supplier_arrangement.amount_due_recorded
    departure.offering_created
    departure.offering_updated
    departure.offering_choice_added
    departure.offering_choice_updated
    departure.offering_choice_removed
    departure.offering_option_added
    departure.offering_option_updated
    departure.offering_option_removed
    departure.offering_price_set
    departure.offering_price_removed
    departure.client_terms_created
    departure.client_terms_copied
    departure.client_terms_updated
    departure.client_cancellation_tier_saved
    departure.client_cancellation_tier_removed
    departure.client_schedule_line_saved
    departure.client_schedule_line_removed
    agency.client_terms_defaults_updated
    agency.cancellation_tier_saved
    agency.cancellation_tier_removed
    departure.task_created
    departure.task_due_changed
    departure.task_started
    departure.task_completed
    departure.task_waived
    departure.task_reopened
    departure.task_reassigned
    departure.team_member_added
    departure.team_member_removed
    departure.default_task_owner_changed
    departure.ready_to_sell
    departure.returned_to_draft
    departure.offering_published
    departure.offering_withdrawn
    departure.departed
  ].freeze

  ACTOR_KINDS = %w[agency_user system].freeze
  SUBJECT_TYPES = %w[Agency AgencyUser Office ClientPerson Client ClientOrganization Supplier SupplierLocation SupplierContact Departure TravelerType SupplierArrangement Traveler ClientTrip ClientBooking SupplierReservation ClientPayment SupplierPayment Reseller].freeze

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
