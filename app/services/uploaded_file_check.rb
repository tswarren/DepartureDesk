# Checks an uploaded file under the ADR 0019 amendments: 20 MB at most,
# a type sniffed from the bytes alone (PDF, PNG, JPEG, .docx or .xlsx),
# and no Office file carrying macros or ActiveX controls. Returns the
# content type and the SHA-256 of the bytes.
module UploadedFileCheck
  CONTENT_TYPES = ArrangementDocument::CONTENT_TYPES
  OFFICE_CONTENT_TYPES = ArrangementDocument::OFFICE_CONTENT_TYPES
  MAX_BYTES = ArrangementDocument::MAX_BYTES
  # Zip entry names are stored uncompressed, so these parts show in the bytes.
  ACTIVE_CONTENT_MARKERS = [ "vbaProject", "activeX" ].freeze

  private

  def inspect_file!(io, label: "Documents")
    io.rewind
    raise AgencyCommand::Error.new("#{label} must be 20 MB or smaller.", code: :invalid) if io.size > MAX_BYTES

    content_type = Marcel::MimeType.for(io)
    io.rewind
    unless content_type.in?(CONTENT_TYPES.keys)
      raise AgencyCommand::Error.new("#{label} must be PDF, PNG, JPEG, Word (.docx) or Excel (.xlsx).", code: :invalid)
    end

    bytes = io.read
    io.rewind
    if content_type.in?(OFFICE_CONTENT_TYPES) && ACTIVE_CONTENT_MARKERS.any? { |marker| bytes.include?(marker) }
      raise AgencyCommand::Error.new("Office files with macros or ActiveX controls can't be uploaded. Save it as .docx or .xlsx without macros, or as PDF.", code: :invalid)
    end

    [ content_type, Digest::SHA256.hexdigest(bytes) ]
  end

  def upload_io(upload) = upload.respond_to?(:tempfile) ? upload.tempfile : upload

  def upload_filename(upload, fallback = "document")
    name = upload.respond_to?(:original_filename) ? upload.original_filename : fallback
    File.basename(name.to_s).presence || fallback
  end
end
