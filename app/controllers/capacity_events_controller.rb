# Supply changes on a confirmed group (INV-26): an increase, a supplier
# release, or a correction. Each form carries an idempotency key. A refused
# change re-renders the group with what was typed and the message on the
# field it names (UX consolidation audit C1).
class CapacityEventsController < ApplicationController
  include ArrangementAccess

  FIELDS = %i[kind quantity unit_shell_id direction corrects_event_id effective_on evidence_note].freeze
  FORM_KINDS = %w[increase supplier_release correction].freeze

  before_action :require_arrangement_view!
  before_action :require_arrangement_management!
  before_action :set_departure
  before_action :set_arrangement

  def create
    group = @arrangement.inventory_groups.find(params[:group_id])
    context = { agency: Current.agency, actor: Current.agency_user, departure: @departure, arrangement: @arrangement, group:,
                effective_on: params[:effective_on], evidence_note: params[:evidence_note], idempotency_key: params[:idempotency_key] }
    case params[:kind]
    when "increase" then IncreaseCapacity.new(**context, quantity: params[:quantity]).call
    when "supplier_release" then RecordSupplierRelease.new(**context, quantity: params[:quantity], unit_shell_id: params[:unit_shell_id]).call
    when "correction" then CorrectCapacity.new(**context, direction: params[:direction], quantity: params[:quantity], corrects_event_id: params[:corrects_event_id]).call
    else raise AgencyCommand::Error.new("Choose a change to record.", code: :invalid)
    end
    redirect_to departure_arrangement_group_path(@departure, @arrangement, group, anchor: "capacity"), notice: "Capacity change recorded."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @group = @arrangement.inventory_groups.find(params[:group_id])
    @capacity_change = { message: error.message, field: error_field(error.message), values: params.permit(*FIELDS).to_h }
    render "inventory_groups/show", status: :unprocessable_entity
  end

  private

  # The id of the field a message is about, as the capacity form names it.
  def error_field(message)
    kind = params[:kind]
    case message
    when /shell|already returned/ then "supplier_release_unit_shell_id"
    when /whole number|below/ then (kind == "supplier_release" && @group.represented_as_unit_shells? ? "supplier_release_unit_shell_id" : "#{kind}_quantity") if FORM_KINDS.include?(kind)
    when /effective date/ then "effective_on"
    when /event this corrects/ then "correction_event"
    when /up or down/ then "correction_direction"
    end
  end
end
