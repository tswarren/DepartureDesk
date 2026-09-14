class FindClientPersonDuplicates
  Candidate = Data.define(:id, :display_name, :status, :signals)

  def self.call(agency:, actor:, names:, emails: [], phones: [], postal_codes: [], exclude_person_id: nil)
    new(agency:, actor:, names:, emails:, phones:, postal_codes:, exclude_person_id:).call
  end

  def initialize(agency:, actor:, names:, emails:, phones:, postal_codes:, exclude_person_id:)
    @agency = agency
    @actor = actor
    @names = names
    @emails = emails
    @phones = phones
    @postal_codes = postal_codes
    @exclude_person_id = exclude_person_id
    @signals = Hash.new { |hash, key| hash[key] = [] }
  end

  def call
    unless @actor&.active? && @actor.agency_id == @agency&.id && @actor.permitted?(:manage_client_directory)
      raise AgencyCommand::Error.new(AgencyCommand::UNAUTHORIZED, code: :unauthorized)
    end

    match_names
    match_contacts if @actor.permitted?(:view_client_contact_details)
    load_candidates
  end

  private

  def people
    scope = @agency.client_people
    scope = scope.where.not(id: @exclude_person_id) if @exclude_person_id
    scope
  end

  def match_names
    full_name = SearchNormalizer.normalize([ @names[:first_name], @names[:middle_name], @names[:last_name], @names[:suffix] ].compact_blank.join(" "))
    return if full_name.blank?

    expression = "dd_search_normalize(first_name || ' ' || coalesce(middle_name, '') || ' ' || last_name || ' ' || coalesce(suffix, ''))"
    people.where("#{expression} = ?", full_name).pluck(:id).each do |id|
      add(id, "exact_full_name")
    end

    postal_keys = @postal_codes.filter_map { |code| SearchNormalizer.normalize(code).presence }
    return if postal_keys.empty?

    people.where("#{expression} = ?", full_name)
      .where(id: @agency.client_people.joins(:postal_addresses).where(client_person_postal_addresses: { postal_code_search_key: postal_keys }).select(:id))
      .pluck(:id).each do |id|
        add(id, "exact_full_name_and_postal_code")
      end
  end

  def match_contacts
    emails = @emails.map { |email| email.to_s.strip.downcase }.reject(&:blank?)
    if emails.any?
      ClientPersonEmailAddress.where(agency_id: @agency.id, normalized_address: emails).where.not(client_person_id: @exclude_person_id).pluck(:client_person_id).each do |id|
        add(id, "exact_email")
      end
    end

    @phones.each do |phone|
      scope = ClientPersonPhoneNumber.where(agency_id: @agency.id, normalized_number: phone.normalized_number)
      scope = scope.where.not(client_person_id: @exclude_person_id) if @exclude_person_id
      scope.pluck(:client_person_id, :extension).each do |person_id, extension|
        signal = extension.to_s == phone.extension.to_s ? "exact_phone" : "same_phone_base"
        add(person_id, signal)
      end
    end
  end

  def add(id, signal)
    @signals[id] << signal unless @signals[id].include?(signal)
  end

  def load_candidates
    return [] if @signals.empty?

    people.where(id: @signals.keys).order(:id).map do |person|
      Candidate.new(id: person.id, display_name: person.display_name, status: person.status, signals: @signals[person.id].sort)
    end
  end
end
