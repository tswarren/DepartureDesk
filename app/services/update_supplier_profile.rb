class UpdateSupplierProfile < UpdateRoleProfile
  def initialize(agency:, party:, profile:, office: nil, lock_version: nil, default_currency: nil, portal_url: :omit, payment_term_notes: :omit, commission_notes: :omit, booking_instructions: :omit, payment_instructions: :omit, cancellation_policy_notes: :omit, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @party = party
    @profile = profile
    @office = office
    @lock_version = lock_version
    @default_currency = default_currency
    @portal_url = portal_url
    @payment_term_notes = payment_term_notes
    @commission_notes = commission_notes
    @booking_instructions = booking_instructions
    @payment_instructions = payment_instructions
    @cancellation_policy_notes = cancellation_policy_notes
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  private

  def profile_association
    :supplier_profile
  end

  def role_noun
    "supplier"
  end

  def perform
    ensure_profile_on_party!(@party, @profile)
    unless @profile.active?
      raise Error.new("Inactive roles cannot be updated until they are reactivated.", code: :invalid)
    end

    lock_offices!(@agency, [ @profile.responsible_office, @office ].compact)
    ensure_office_currently_active!(@office) if @office
    ensure_fresh_lock!(@profile, @lock_version)

    changes = guidance_attributes
    office_changed = @office && @profile.responsible_office_id != @office.id
    if office_changed
      changes[:responsible_office] = @office
      changes[:responsible_office_status] = "active"
    end

    return profile_result(:accepted, @party, @profile) if changes.empty?

    previous_office_id = @profile.responsible_office_id
    @profile.update!(changes)
    extra = { "changed_fields" => changes.keys.map(&:to_s) }
    extra["previous_responsible_office_id"] = previous_office_id if office_changed
    audit_profile!(@profile, "directory.supplier_profile_updated", extra)
    profile_result(:accepted, @party, @profile)
  end

  def guidance_attributes
    attributes = {}
    if @default_currency.present? && @default_currency != @profile.default_currency
      attributes[:default_currency] = @default_currency
    end
    unless @portal_url == :omit
      value = @portal_url.to_s.strip.presence
      attributes[:portal_url] = value unless value == @profile.portal_url
    end
    SupplierProfile::NOTE_ATTRIBUTES.each do |attribute|
      provided = instance_variable_get(:"@#{attribute}")
      next if provided == :omit

      value = provided.to_s.strip.presence
      attributes[attribute] = value unless value == @profile.public_send(attribute)
    end
    attributes
  end
end
