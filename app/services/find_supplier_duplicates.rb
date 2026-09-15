class FindSupplierDuplicates
  Candidate = Data.define(:id, :display_name, :status, :signals)

  def self.call(agency:, actor:, kind:, names:, emails: [], phones: [], postal_codes: [], localities: [], websites: [], exclude_supplier_id: nil)
    new(agency:, actor:, kind:, names:, emails:, phones:, postal_codes:, localities:, websites:, exclude_supplier_id:).call
  end

  def initialize(agency:, actor:, kind:, names:, emails:, phones:, postal_codes:, localities:, websites:, exclude_supplier_id:)
    @agency = agency
    @actor = actor
    @kind = kind.to_s
    @names = names.to_h.symbolize_keys
    @emails = emails
    @phones = phones
    @postal_codes = postal_codes
    @localities = localities
    @websites = websites
    @exclude_supplier_id = exclude_supplier_id
    @signals = Hash.new { |hash, key| hash[key] = [] }
  end

  def call
    unless @actor&.active? && @actor.agency_id == @agency&.id && @actor.permitted?(:manage_supplier_directory)
      raise AgencyCommand::Error.new(AgencyCommand::UNAUTHORIZED, code: :unauthorized)
    end
    raise AgencyCommand::Error.new("Choose organization or individual.", code: :invalid) unless Supplier::KINDS.include?(@kind)

    match_names
    match_name_and_location
    match_contacts if @actor.permitted?(:view_supplier_contact_details)
    load_candidates
  end

  private

  def suppliers
    scope = @agency.suppliers.where(kind: @kind)
    scope = scope.where.not(id: @exclude_supplier_id) if @exclude_supplier_id
    scope
  end

  def match_names
    display_name = SearchNormalizer.normalize(@names[:display_name])
    legal_name = SearchNormalizer.normalize(@names[:legal_name])
    doing_business_as = SearchNormalizer.normalize(@names[:doing_business_as])
    individual_name = SearchNormalizer.normalize([ @names[:first_name], @names[:last_name] ].compact_blank.join(" "))

    if @kind == "organization"
      match_name(display_name, "exact_display_name") if display_name.present?
      match_legal_name(legal_name) if legal_name.present?
    elsif individual_name.present?
      suppliers.where(individual_full_name_search_key: individual_name).pluck(:id).each { |id| add(id, "exact_individual_full_name") }
    end
    match_name(doing_business_as, "exact_doing_business_as") if doing_business_as.present?
  end

  def match_legal_name(value)
    suppliers.where(legal_name_search_key: value).pluck(:id).each { |id| add(id, "exact_legal_name") }
  end

  def match_name(value, signal)
    suppliers.where(display_name_search_key: value).or(suppliers.where(doing_business_as_search_key: value)).pluck(:id).each do |id|
      add(id, signal)
    end
  end

  def match_name_and_location
    name_keys = supplier_name_keys
    return if name_keys.empty?

    named = suppliers.where(display_name_search_key: name_keys)
      .or(suppliers.where(legal_name_search_key: name_keys))
      .or(suppliers.where(doing_business_as_search_key: name_keys))
      .or(suppliers.where(individual_full_name_search_key: name_keys))

    postal_keys = @postal_codes.filter_map { |code| SearchNormalizer.normalize(code).presence }
    if postal_keys.any?
      postal_ids = SupplierPostalAddress.where(agency_id: @agency.id, postal_code_search_key: postal_keys)
      postal_ids = postal_ids.where.not(supplier_id: @exclude_supplier_id) if @exclude_supplier_id
      named.where(id: postal_ids.select(:supplier_id)).pluck(:id).each { |id| add(id, "name_and_postal_code") }
    end

    locality_keys = @localities.filter_map { |locality| SearchNormalizer.normalize(locality).presence }
    return if locality_keys.empty?

    locality_ids = SupplierPostalAddress.where(agency_id: @agency.id, locality_search_key: locality_keys)
    locality_ids = locality_ids.where.not(supplier_id: @exclude_supplier_id) if @exclude_supplier_id
    named.where(id: locality_ids.select(:supplier_id)).pluck(:id).each { |id| add(id, "name_and_locality") }
  end

  def match_contacts
    emails = @emails.map { |email| email.to_s.strip.downcase }.reject(&:blank?)
    if emails.any?
      scope = SupplierEmailAddress.where(agency_id: @agency.id, normalized_address: emails)
      scope = scope.where.not(supplier_id: @exclude_supplier_id) if @exclude_supplier_id
      scope.pluck(:supplier_id).each { |id| add(id, "exact_email") }
    end

    @phones.each do |phone|
      scope = SupplierPhoneNumber.where(agency_id: @agency.id, normalized_number: phone.normalized_number)
      scope = scope.where.not(supplier_id: @exclude_supplier_id) if @exclude_supplier_id
      scope.pluck(:supplier_id, :extension).each do |supplier_id, extension|
        add(supplier_id, extension.to_s == phone.extension.to_s ? "exact_phone" : "same_phone_base")
      end
    end

    hosts = @websites.filter_map { |website| website.normalized_host.presence }
    return if hosts.empty?

    scope = SupplierWebsite.where(agency_id: @agency.id, normalized_host: hosts)
    scope = scope.where.not(supplier_id: @exclude_supplier_id) if @exclude_supplier_id
    scope.pluck(:supplier_id).each { |id| add(id, "same_website_host") }
  end

  def supplier_name_keys
    [
      @names[:display_name],
      @names[:legal_name],
      @names[:doing_business_as],
      [ @names[:first_name], @names[:last_name] ].compact_blank.join(" ")
    ].filter_map { |value| SearchNormalizer.normalize(value).presence }.uniq
  end

  def add(id, signal)
    @signals[id] << signal unless @signals[id].include?(signal)
  end

  def load_candidates
    return [] if @signals.empty?

    suppliers.where(id: @signals.keys).order(:id).map do |supplier|
      Candidate.new(id: supplier.id, display_name: supplier.display_name_for_directory, status: supplier.status, signals: @signals[supplier.id].sort)
    end
  end
end
