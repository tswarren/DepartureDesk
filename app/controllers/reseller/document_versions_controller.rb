# R-04: the reseller downloads its bookings' confirmations only (DOC-21,
# DOC-24); their invoices and receipts are not found.
class Reseller::DocumentVersionsController < ::DocumentVersionsController
  include ResellerArea

  private

  def require_document_access! = require_permission!(:reseller_issue_confirmation)

  def document_scope = reseller_scope.document_versions
end
