# Records a supplier obligation directly as an amount due (SMN-05).
class DirectAmountsDueController < ApplicationController
  include SupplierMoneyAccess

  before_action :require_arrangement_view!
  before_action :require_supplier_cost_view!
  before_action -> { require_permission!(:record_amounts_due) }
  before_action :set_departure
  before_action :set_arrangement

  def new
    @amount_due = @arrangement.amounts_due.new
    @values = {}
  end

  def create
    RecordDirectAmountDue.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, arrangement: @arrangement,
      attributes: money_params(:amount_due, %i[description amount due_on])).call
    redirect_to_money "Amount due recorded.", anchor: "supplier-payments"
  rescue AgencyCommand::Error => error
    @amount_due = @arrangement.amounts_due.new
    @values = money_params(:amount_due, %i[description amount due_on])
    render_money_error(error, @amount_due, :new, [ [ :amount, "Amount" ], [ :description, "Description" ], [ :due_on, "Due date" ] ])
  end
end
