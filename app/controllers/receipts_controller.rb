# An agency receipt, as issued (CMN-55). Its PDF arrives in build step 10.
class ReceiptsController < ApplicationController
  before_action -> { require_permission!(:view_client_money) }

  def show
    @receipt = Current.agency.receipts.find(params[:id])
    @payment = @receipt.client_payment
  end
end
