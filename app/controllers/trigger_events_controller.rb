# Records a trigger event on a confirmed arrangement (SMN-11 to SMN-14).
class TriggerEventsController < ApplicationController
  include SupplierMoneyAccess

  before_action :require_arrangement_view!
  before_action :require_supplier_cost_view!
  before_action :require_arrangement_management!
  before_action :set_departure
  before_action :set_arrangement

  def new
  end

  def create
    event = params.fetch(:trigger_event, {})
    RecordTriggerEvent.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, arrangement: @arrangement,
      event_type: event[:event_type], occurred_on: event[:occurred_on], count: event[:count], reference: event[:reference]).call
    redirect_to_money "Event recorded.", anchor: "supplier-payments"
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @error = error.message
    render :new, status: :unprocessable_entity
  end
end
