# Uploads, replaces or removes the agency logo (SET-08, SET-13). Only an
# Agency Admin may call it. Pass upload: nil to remove the logo.
class UpdateAgencyLogo < AgencyCommand
  def initialize(agency:, actor:, upload:)
    @agency = agency
    @actor = actor
    @upload = upload
  end

  def call
    ActiveRecord::Base.transaction do
      @agency.with_lock do
        ensure_permitted!(@actor, :manage_agency_profile)
        ensure_active_agency!(@agency)
        @upload ? attach! : remove!
      end
    end
    Result.new(status: :accepted, record: @agency)
  end

  private

  def attach!
    ensure_image_bytes!
    @agency.logo.attach(@upload)
    unless @agency.valid?
      message = @agency.errors.messages_for(:logo).map { |error| "Logo #{error}" }.to_sentence
      raise Error.new(message.presence || @agency.errors.full_messages.to_sentence, code: :invalid)
    end
    @agency.save!
    blob = @agency.logo.blob
    audit!(
      agency: @agency, action: "agency.logo_updated", subject: @agency, actor: @actor,
      details: { "agency_id" => @agency.id, "content_type" => blob.content_type, "byte_size" => blob.byte_size, "checksum" => blob.checksum }
    )
  end

  # The declared content type comes from the browser; check the bytes too.
  def ensure_image_bytes!
    io = @upload.respond_to?(:tempfile) ? @upload.tempfile : @upload
    sniffed = Marcel::MimeType.for(io)
    io.rewind if io.respond_to?(:rewind)
    return if sniffed.in?(Agency::LOGO_CONTENT_TYPES)

    raise Error.new("Logo must be a PNG, JPEG or WebP image", code: :invalid)
  end

  def remove!
    return unless @agency.logo.attached?

    @agency.logo.purge_later
    audit!(agency: @agency, action: "agency.logo_removed", subject: @agency, actor: @actor, details: { "agency_id" => @agency.id })
  end
end
