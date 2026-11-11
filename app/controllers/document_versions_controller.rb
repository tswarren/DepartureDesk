# Downloads an issued document's stored PDF (ADR 0019, DOC-21): loaded
# through the agency, checked against its SHA-256, sent inline under a
# sandbox. Every download serves the bytes stored at issue; nothing is
# rendered again. Another agency's version is not found.
class DocumentVersionsController < ApplicationController
  before_action :require_document_access!

  def show
    version = document_scope.find(params[:id])
    data = version.pdf.download
    raise "Document version #{version.id} failed its SHA-256 check" unless Digest::SHA256.hexdigest(data) == version.sha256

    response.headers["Content-Security-Policy"] = "default-src 'none'; sandbox"
    send_data data, filename: version.filename, type: "application/pdf", disposition: "inline"
  end

  private

  def require_document_access! = require_permission!(:issue_documents)

  def document_scope = Current.agency.document_versions
end
