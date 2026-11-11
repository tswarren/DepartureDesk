# S-35: issues a confirmed booking's confirmation or invoice (DOC-01,
# DOC-11; step 10 plan, questions 1 to 3). The reseller's subclass issues
# the confirmation only (R-04); the command enforces it.
class BookingDocumentsController < ApplicationController
  include BookingAccess

  before_action :set_booking

  def create
    type = params[:document_type].to_s
    run_booking_command("documents", "#{DocumentVersion::TYPE_LABELS.fetch(type, "Document")} issued.", step: "summary") do
      IssueDocument.new(agency: Current.agency, actor: Current.agency_user, document_type: type, booking: @booking).call
    end
  end

  private

  def require_booking_management! = require_permission!(:issue_documents)
end
