# An agency receipt, as issued (CMN-55), with its PDF (S-35, step 10).
class ReceiptsController < ApplicationController
  before_action -> { require_permission!(:view_client_money) }

  def show
    @receipt = Current.agency.receipts.includes(document_versions: [ :issued_by, { deliveries: :recorded_by } ]).find(params[:id])
    @payment = @receipt.client_payment
  end
end
