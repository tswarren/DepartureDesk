# Attaches a supplier document to an arrangement (ADR 0019 amendment). The
# type comes from the bytes, never the name or the browser's label, and an
# Office file carrying macros or ActiveX controls is refused.
class UploadArrangementDocument < AgencyCommand
  include ArrangementCommandSupport

  # Zip entry names are stored uncompressed, so these parts show in the bytes.
  ACTIVE_CONTENT_MARKERS = [ "vbaProject", "activeX" ].freeze

  def initialize(agency:, actor:, departure:, arrangement:, upload:, kind:, description: nil)
    @agency = agency
    @actor = actor
    @departure = departure
    @arrangement = arrangement
    @upload = upload
    @kind = kind.to_s
    @description = description
  end

  def call
    ensure_departure_actor!(:manage_arrangements)
    raise Error.new("Choose a file.", code: :invalid) if @upload.blank?
    raise Error.new("Choose what kind of document this is.", code: :invalid) unless @kind.in?(ArrangementDocument::KINDS)

    io = @upload.respond_to?(:tempfile) ? @upload.tempfile : @upload
    content_type, sha256 = inspect_file!(io)

    ActiveRecord::Base.transaction do
      departure = lock_arrangement_context!
      arrangement = lock_arrangement!(departure)
      raise Error.new("A cancelled arrangement can't take documents.", code: :invalid_state) if arrangement.cancelled?

      document = arrangement.documents.create!(
        agency: @agency, kind: @kind, description: @description, uploaded_by: @actor, sha256:
      )
      document.file.attach(io: io, filename: original_filename, content_type:, identify: false)
      audit!(
        agency: @agency, action: "supplier_arrangement.document_added", subject: arrangement, actor: @actor,
        details: { "arrangement_document_id" => document.id, "filename" => original_filename, "kind" => @kind,
                   "content_type" => content_type, "byte_size" => io.size, "sha256" => sha256 }
      )
      Result.new(status: :created, record: document)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def inspect_file!(io)
    io.rewind
    raise Error.new("Documents must be 20 MB or smaller.", code: :invalid) if io.size > ArrangementDocument::MAX_BYTES

    content_type = Marcel::MimeType.for(io)
    io.rewind
    unless content_type.in?(ArrangementDocument::CONTENT_TYPES.keys)
      raise Error.new("Documents must be PDF, PNG, JPEG, Word (.docx) or Excel (.xlsx).", code: :invalid)
    end

    bytes = io.read
    io.rewind
    if content_type.in?(ArrangementDocument::OFFICE_CONTENT_TYPES) && ACTIVE_CONTENT_MARKERS.any? { |marker| bytes.include?(marker) }
      raise Error.new("Office files with macros or ActiveX controls can't be uploaded. Save it as .docx or .xlsx without macros, or as PDF.", code: :invalid)
    end

    [ content_type, Digest::SHA256.hexdigest(bytes) ]
  end

  def original_filename
    name = @upload.respond_to?(:original_filename) ? @upload.original_filename : "document"
    File.basename(name.to_s).presence || "document"
  end
end
