# R-04: the reseller records how it delivered its booking's confirmation (DOC-21).
class Reseller::DocumentDeliveriesController < ::DocumentDeliveriesController
  include ResellerArea

  private

  def require_document_access! = require_permission!(:reseller_issue_confirmation)

  def document_scope = reseller_scope.document_versions

  def return_path = reseller_client_booking_path(@version.client_booking_id, step: "summary", anchor: "documents")
end
