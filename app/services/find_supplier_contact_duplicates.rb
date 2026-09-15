class FindSupplierContactDuplicates
  Candidate = Data.define(:id, :display_name, :status, :signals)

  def self.call(agency:, actor:, supplier:, first_name:, last_name:, emails: [], phones: [], exclude_contact_id: nil)
    new(agency:, actor:, supplier:, first_name:, last_name:, emails:, phones:, exclude_contact_id:).call
  end

  def initialize(agency:, actor:, supplier:, first_name:, last_name:, emails:, phones:, exclude_contact_id:)
    @agency = agency
    @actor = actor
    @supplier = supplier
    @first_name = first_name
    @last_name = last_name
    @emails = emails
    @phones = phones
    @exclude_contact_id = exclude_contact_id
    @signals = Hash.new { |hash, key| hash[key] = [] }
  end

  def call
    unless @actor&.active? && @actor.agency_id == @agency&.id && @actor.permitted?(:manage_supplier_directory)
      raise AgencyCommand::Error.new(AgencyCommand::UNAUTHORIZED, code: :unauthorized)
    end
    raise ActiveRecord::RecordNotFound if @supplier.blank? || @supplier.agency_id != @agency.id

    match_names
    match_emails
    match_phones
    load_candidates
  end

  private

  def contacts
    scope = @agency.supplier_contacts.where(supplier_id: @supplier.id)
    scope = scope.where.not(id: @exclude_contact_id) if @exclude_contact_id
    scope
  end

  def match_names
    first_key = SearchNormalizer.normalize(@first_name)
    last_key = SearchNormalizer.normalize(@last_name)
    return if first_key.blank? || last_key.blank?

    contacts.where(first_name_search_key: first_key, last_name_search_key: last_key).pluck(:id).each do |id|
      add(id, "same_name")
    end
  end

  def match_emails
    emails = Array(@emails).map { |email| email.to_s.strip.downcase }.reject(&:blank?)
    return if emails.empty?

    email_destinations.where(normalized_address: emails).pluck(:supplier_contact_id).each do |id|
      add(id, "exact_email")
    end
  end

  def match_phones
    Array(@phones).each do |phone|
      phone_destinations.where(normalized_number: phone.normalized_number).pluck(:supplier_contact_id, :extension).each do |contact_id, extension|
        add(contact_id, extension.to_s == phone.extension.to_s ? "exact_phone" : "same_phone_base")
      end
    end
  end

  def email_destinations
    scope = SupplierContactEmailAddress
      .joins(:supplier_contact)
      .where(agency_id: @agency.id, supplier_contacts: { supplier_id: @supplier.id })
    scope = scope.where.not(supplier_contact_id: @exclude_contact_id) if @exclude_contact_id
    scope
  end

  def phone_destinations
    scope = SupplierContactPhoneNumber
      .joins(:supplier_contact)
      .where(agency_id: @agency.id, supplier_contacts: { supplier_id: @supplier.id })
    scope = scope.where.not(supplier_contact_id: @exclude_contact_id) if @exclude_contact_id
    scope
  end

  def add(id, signal)
    @signals[id] << signal unless @signals[id].include?(signal)
  end

  def load_candidates
    return [] if @signals.empty?

    contacts.where(id: @signals.keys).order(:id).map do |contact|
      Candidate.new(
        id: contact.id,
        display_name: contact.display_name_for_directory,
        status: contact.status,
        signals: @signals[contact.id].sort
      )
    end
  end
end
