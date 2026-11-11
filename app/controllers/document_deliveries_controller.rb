# Records a manual delivery of an issued document (DOC-21), then returns to
# the page the document is listed on.
class DocumentDeliveriesController < ApplicationController
  before_action :require_document_access!

  def create
    @version = document_scope.find(params[:document_version_id])
    RecordDocumentDelivery.new(agency: Current.agency, actor: Current.agency_user, version: @version,
      attributes: params.fetch(:document_delivery, {}).permit(:delivery_method, :recipient, :delivered_on).to_h).call
    redirect_to return_path, notice: "Delivery of #{@version.display_number} recorded."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to return_path, alert: error.message
  end

  private

  def require_document_access! = require_permission!(:issue_documents)

  def document_scope = Current.agency.document_versions

  def return_path
    if @version.receipt_id
      receipt_path(@version.receipt_id, anchor: "documents")
    else
      client_booking_path(@version.client_booking_id, step: "summary", anchor: "documents")
    end
  end
end
