# Shared by the traveler and Client Trip commands (CLT-05 to CLT-11, CLT-28,
# CLT-02, OVR-02). Every staff user may manage them (ACC-30).
module TravelerCommandSupport
  TRAVELER_FIELDS = %w[given_names middle_name surname suffix preferred_name date_of_birth gender email_address phone].freeze

  private

  def ensure_actor!(action)
    ensure_directory_actor!(@actor, @agency, action)
    ensure_active_agency!(@agency)
  end

  def clean(attributes, fields)
    attributes.to_h.stringify_keys.slice(*fields).transform_values { |value| value.is_a?(String) ? value.strip.presence : value }
  end

  def ensure_version!(record)
    return if @lock_version.nil? || record.lock_version == @lock_version.to_i

    raise AgencyCommand::Error.new("This record changed. Reload it and try again.", code: :conflict)
  end

  def active_client!(client_id)
    client = @agency.clients.lock.find_by(id: client_id)
    raise AgencyCommand::Error.new("Client must be chosen.", code: :invalid) if client.nil?
    raise AgencyCommand::Error.new("Client is inactive and can't be used.", code: :invalid) unless client.active?

    client
  end

  def invalid!(error)
    raise AgencyCommand::Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  def link_traveler!(client, traveler, relationship)
    link = @agency.traveler_links.create!(client:, traveler:, relationship:)
    audit!(agency: @agency, action: "client.traveler_linked", subject: client, actor: @actor,
      details: { "traveler_id" => traveler.id, "relationship" => relationship })
    link
  end
end
