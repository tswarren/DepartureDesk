# S-26: the booking workspace, and creating a draft booking from its trip.
class ClientBookingsController < ApplicationController
  include BookingAccess
  include TripAccess

  before_action :set_booking, only: :show

  def show
    @booking = booking_scope
      .includes(:offering, :owner_reseller, :seller_reseller, { created_by: :reseller }, :client_terms_version, client_trip: [ :departure, { client: %i[client_person client_organization] } ],
        booking_travelers: %i[traveler traveler_type],
        choice_selections: [ :occupants, :inventory_allocations, { supplier_reservation_units: :supplier_reservation },
                             { option: [ :choice, { inventory_group: [ :capacity_rules, { supplier_arrangement: :supplier } ] } ] } ],
        inventory_allocations: %i[inventory_group unit_shell choice_selection],
        price_lines: [ :booking_traveler, { choice_selection: { option: :choice } } ],
        acceptances: [ :recorded_by, :client_terms_version, :client_payment, { evidence_attachment: :blob } ], cost_lines: :schedule_lines,
        installment_proposals: [], client_charge: { installments: { applications: { client_payment: %i[payer receipt reversal] } } },
        expected_commissions: [ :overridden_by, :confirmed_by, { choice_selection: { option: :choice } } ],
        document_versions: [ :issued_by, { deliveries: :recorded_by } ])
      .find(@booking.id)
    @trip = @booking.client_trip
    @choices = @booking.offering.choices.includes(options: :inventory_group)
    @blockers = BookingConfirmationCheck.new(@booking).blockers
    on_booking = @booking.booking_travelers.map(&:traveler_id)
    @linked_travelers = linkable_travelers.includes(:traveler).sort_by { |link| [ link.related_as_self? ? 0 : 1, link.created_at ] }
      .reject { |link| on_booking.include?(link.traveler_id) }
    @traveler_types = Current.agency.traveler_types.active.ordered
    @traveler_query = params[:traveler_q].to_s.squish
    @found_travelers = @traveler_query.length >= 2 && directory_search? ? Current.agency.travelers.matching(@traveler_query, unlinked_from: @trip.client, limit: 10).to_a : []
    @blocked = flash[:blockers]
    @progress = BookingProgress.new(@booking, @blockers)
    @step = params[:step].presence_in(@progress.available) || @progress.current
  end

  def create
    trip = Current.agency.client_trips.find(params[:client_trip_id])
    result = CreateClientBooking.new(agency: Current.agency, actor: Current.agency_user, trip:).call
    redirect_to client_booking_path(result.record), notice: "Booking #{result.record.booking_reference} created as a draft."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to client_trip_path(trip), alert: error.message
  end

  private

  # The client's travelers offered for adding to the booking.
  def linkable_travelers = @trip.client.traveler_links

  def directory_search? = Current.agency_user.permitted?(:manage_client_directory)
end
