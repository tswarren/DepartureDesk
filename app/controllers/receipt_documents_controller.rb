# S-35: issues an agency receipt's PDF (DOC-01, CMN-55; step 10 plan,
# question 1). It keeps the receipt's own number.
class ReceiptDocumentsController < ApplicationController
  before_action -> { require_permission!(:issue_documents) }

  def create
    receipt = Current.agency.receipts.find(params[:receipt_id])
    IssueDocument.new(agency: Current.agency, actor: Current.agency_user, document_type: "receipt", receipt:).call
    redirect_to receipt_path(receipt, anchor: "documents"), notice: "Receipt PDF issued."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to receipt_path(receipt, anchor: "documents"), alert: error.message
  end
end
