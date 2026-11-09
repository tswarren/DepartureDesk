class DepartureDecisionsController < ApplicationController
  include DepartureAccess

  ERROR_FIELDS = [ [ :note, "Note" ] ].freeze

  before_action :require_departure_view!
  before_action :require_departure_management!
  before_action :set_departure

  def create
    RecordDepartureDecision.new(
      agency: Current.agency,
      actor: Current.agency_user,
      departure: @departure,
      decision: params.dig(:departure_decision, :decision),
      note: params.dig(:departure_decision, :note),
      lock_version: params.dig(:departure_decision, :lock_version)
    ).call
    redirect_to departure_path(@departure, anchor: "decision"), notice: "Decision recorded."
  rescue AgencyCommand::Error => error
    # UX consolidation audit C1: re-render the overview with the note kept.
    @decision = DepartureDecision.new(note: params.dig(:departure_decision, :note))
    @departure.reload
    @summary = DepartureSummary.for([ @departure ]).fetch(@departure)
    render_form_error(error, @decision, "departures/show", ERROR_FIELDS)
  end
end
