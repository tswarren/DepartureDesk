# Records a delivery of an issued document made outside the app (DOC-21):
# own email, printed or in person, to a recipient on a date. Anyone who may
# download the version may record it: staff for every document, the reseller
# that owns the booking for its confirmation (DOC-24, R-04). Nothing is sent.
class RecordDocumentDelivery < AgencyCommand
  FIELDS = %w[delivery_method recipient delivered_on].freeze

  def initialize(agency:, actor:, version:, attributes:)
    @agency = agency
    @actor = actor
    @version = version
    @attributes = attributes.to_h.stringify_keys.slice(*FIELDS).transform_values { |value| value.is_a?(String) ? value.strip.presence : value }
  end

  def call
    version = authorized_version!
    ensure_active_agency!(@agency)
    raise Error.new("Method must be chosen.", code: :invalid) unless @attributes["delivery_method"].in?(DocumentDelivery::METHODS)
    raise Error.new("Recipient must be given.", code: :invalid) if @attributes["recipient"].blank?

    ActiveRecord::Base.transaction do
      @agency.lock!
      delivery = version.deliveries.create!(agency: @agency, delivery_method: @attributes["delivery_method"], recipient: @attributes["recipient"],
        delivered_on: delivered_on, recorded_by: @actor, recorded_at: Clock.current.now)
      audit!(agency: @agency, action: "document_version.delivery_recorded", subject: version, actor: @actor, details: {
        "document_delivery_id" => delivery.id, "number" => version.display_number, "delivery_method" => delivery.delivery_method, "delivered_on" => delivery.delivered_on.iso8601
      })
      Result.new(status: :created, record: delivery)
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def authorized_version!
    if reseller_actor?
      ensure_reseller_actor!(:reseller_issue_confirmation)
      ResellerScope.new(@actor).document_versions.find(@version.id)
    else
      ensure_directory_actor!(@actor, @agency, :issue_documents)
      @agency.document_versions.find(@version.id)
    end
  end

  # A date that doesn't parse is refused; a future date too.
  def delivered_on
    value = @attributes["delivered_on"]
    day = value.is_a?(Date) ? value : Date.iso8601(value.to_s)
    raise Error.new("Date delivered can't be in the future.", code: :invalid) if day > Clock.current.today_in(@agency.default_timezone)

    day
  rescue Date::Error
    raise Error.new("Date delivered must be a date, such as 2027-02-03.", code: :invalid)
  end
end
