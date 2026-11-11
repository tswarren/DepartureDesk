# S-35 and R-04: the documents a booking or receipt can have, each issued
# or not, with what the current user may do (DOC-01, DOC-21, DOC-24).
module DocumentsHelper
  Row = Data.define(:type, :label, :version, :issue_url, :download_url, :deliveries_url, :reason)

  # The confirmation, and for staff the invoice, of a booking (R-04 hides the invoice from a reseller).
  def booking_document_rows(booking)
    types = reseller_area? ? %w[confirmation] : %w[confirmation invoice]
    can_issue = Current.agency_user.permitted?(reseller_area? ? :reseller_issue_confirmation : :issue_documents)
    types.map do |type|
      version = booking.document_versions.find { |candidate| candidate.document_type == type }
      reason = "Issued once the booking is confirmed." unless booking.status_confirmed?
      document_row(type, version, can_issue && reason.nil? ? booking_route(:client_booking_documents, booking, document_type: type) : nil, reason)
    end
  end

  def receipt_document_rows(receipt)
    version = receipt.document_versions.first
    can_issue = Current.agency_user.permitted?(:issue_documents)
    [ document_row("receipt", version, can_issue ? receipt_document_path(receipt) : nil, nil) ]
  end

  def document_issued_line(version)
    "Issued #{version.issued_at.in_time_zone(Current.agency.default_timezone).strftime("%b %-d, %Y")} by #{version.issued_by.display_name}"
  end

  private

  def document_row(type, version, issue_url, reason)
    reseller = reseller_area?
    Row.new(type:, label: DocumentVersion::TYPE_LABELS.fetch(type), version:, issue_url: (issue_url unless version), reason: (reason unless version),
      download_url: version && (reseller ? reseller_document_version_path(version) : document_version_path(version)),
      deliveries_url: version && (reseller ? reseller_document_version_deliveries_path(version) : document_version_deliveries_path(version)))
  end
end
