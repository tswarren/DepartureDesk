class FindClientOrganizationDuplicates
  Candidate = Data.define(:id, :display_name, :status, :signals)

  def self.call(agency:, actor:, names:, emails: [], phones: [], postal_codes: [], websites: [], exclude_organization_id: nil)
    new(agency:, actor:, names:, emails:, phones:, postal_codes:, websites:, exclude_organization_id:).call
  end

  def initialize(agency:, actor:, names:, emails:, phones:, postal_codes:, websites:, exclude_organization_id:)
    @agency = agency
    @actor = actor
    @names = names.to_h.symbolize_keys
    @emails = emails
    @phones = phones
    @postal_codes = postal_codes
    @websites = websites
    @exclude_organization_id = exclude_organization_id
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

  def organizations
    scope = @agency.client_organizations
    scope = scope.where.not(id: @exclude_organization_id) if @exclude_organization_id
    scope
  end

  def match_names
    display_name = SearchNormalizer.normalize(@names[:display_name])
    legal_name = SearchNormalizer.normalize(@names[:legal_name])

    match_name(display_name, "exact_display_name") if display_name.present?
    match_name(legal_name, "exact_legal_name") if legal_name.present?
  end

  def match_name(value, signal)
    organizations.where(display_name_search_key: value).or(organizations.where(legal_name_search_key: value)).pluck(:id).each do |id|
      add(id, signal)
    end
  end

  def match_contacts
    emails = @emails.map { |email| email.to_s.strip.downcase }.reject(&:blank?)
    ClientOrganizationEmailAddress.where(agency_id: @agency.id, normalized_address: emails).where.not(client_organization_id: @exclude_organization_id).pluck(:client_organization_id).each do |id|
      add(id, "exact_email")
    end if emails.any?

    @phones.each do |phone|
      scope = ClientOrganizationPhoneNumber.where(agency_id: @agency.id, normalized_number: phone.normalized_number)
      scope = scope.where.not(client_organization_id: @exclude_organization_id) if @exclude_organization_id
      scope.pluck(:client_organization_id, :extension).each do |organization_id, extension|
        add(organization_id, extension.to_s == phone.extension.to_s ? "exact_phone" : "same_phone_base")
      end
    end

    postal_keys = @postal_codes.filter_map { |code| SearchNormalizer.normalize(code).presence }
    ClientOrganizationPostalAddress.where(agency_id: @agency.id, postal_code_search_key: postal_keys).where.not(client_organization_id: @exclude_organization_id).pluck(:client_organization_id).each do |id|
      add(id, "exact_postal_code")
    end if postal_keys.any?

    hosts = @websites.filter_map { |website| website.normalized_host.presence }
    ClientOrganizationWebsite.where(agency_id: @agency.id, normalized_host: hosts).where.not(client_organization_id: @exclude_organization_id).pluck(:client_organization_id).each do |id|
      add(id, "same_website_host")
    end if hosts.any?
  end

  def add(id, signal)
    @signals[id] << signal unless @signals[id].include?(signal)
  end

  def load_candidates
    return [] if @signals.empty?

    organizations.where(id: @signals.keys).order(:id).map do |organization|
      Candidate.new(id: organization.id, display_name: organization.display_name, status: organization.status, signals: @signals[organization.id].sort)
    end
  end
end
