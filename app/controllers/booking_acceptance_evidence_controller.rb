# Downloads an acceptance's evidence file (ADR 0019 amendment): loaded
# through the agency, checked against its stored SHA-256, Office files as
# attachments and PDFs and images inline under a sandbox.
class BookingAcceptanceEvidenceController < ApplicationController
  include BookingAccess

  before_action :set_booking

  def show
    acceptance = @booking.acceptances.find(params[:acceptance_id])
    raise ActiveRecord::RecordNotFound unless acceptance.evidence.attached?

    data = acceptance.evidence.download
    raise "Acceptance evidence #{acceptance.id} failed its SHA-256 check" unless Digest::SHA256.hexdigest(data) == acceptance.evidence_sha256

    response.headers["Content-Security-Policy"] = "default-src 'none'; sandbox"
    office = acceptance.evidence.content_type.in?(UploadedFileCheck::OFFICE_CONTENT_TYPES)
    send_data data, filename: acceptance.evidence.filename.to_s, type: acceptance.evidence.content_type, disposition: office ? "attachment" : "inline"
  end
end
