class FindSupplierLocationDuplicates
  Candidate = Data.define(:id, :display_name, :status, :signals)
  UNIT_SEPARATOR = "\u001F"

  def self.call(agency:, actor:, supplier:, name:, address: {}, exclude_location_id: nil)
    new(agency:, actor:, supplier:, name:, address:, exclude_location_id:).call
  end

  def initialize(agency:, actor:, supplier:, name:, address:, exclude_location_id:)
    @agency = agency
    @actor = actor
    @supplier = supplier
    @name = name
    @address = address.to_h.symbolize_keys
    @exclude_location_id = exclude_location_id
    @signals = Hash.new { |hash, key| hash[key] = [] }
  end

  def call
    unless @actor&.active? && @actor.agency_id == @agency&.id && @actor.permitted?(:manage_supplier_directory)
      raise AgencyCommand::Error.new(AgencyCommand::UNAUTHORIZED, code: :unauthorized)
    end
    raise ActiveRecord::RecordNotFound if @supplier.blank? || @supplier.agency_id != @agency.id

    match_exact_postal_address
    match_name_and_locality
    load_candidates
  end

  private

  def locations
    scope = @agency.supplier_locations.where(supplier_id: @supplier.id)
    scope = scope.where.not(id: @exclude_location_id) if @exclude_location_id
    scope
  end

  def match_exact_postal_address
    key = postal_address_search_key
    return if key.blank?

    locations.where(postal_address_search_key: key).pluck(:id).each { |id| add(id, "exact_postal_address") }
  end

  def match_name_and_locality
    name_key = SearchNormalizer.normalize(@name)
    locality_key = SearchNormalizer.normalize(@address[:address_locality])
    return if name_key.blank? || locality_key.blank?

    locations.where(name_search_key: name_key, locality_search_key: locality_key).pluck(:id).each do |id|
      add(id, "name_and_locality")
    end
  end

  def postal_address_search_key
    line_1 = @address[:address_line_1].to_s.strip.presence
    return if line_1.blank?

    [
      SearchNormalizer.normalize(@address[:address_line_1]),
      SearchNormalizer.normalize(@address[:address_line_2]),
      SearchNormalizer.normalize(@address[:address_locality]),
      SearchNormalizer.normalize(@address[:address_region]),
      SearchNormalizer.normalize(@address[:address_postal_code]),
      @address[:address_country_code].to_s.strip.upcase
    ].join(UNIT_SEPARATOR)
  end

  def add(id, signal)
    @signals[id] << signal unless @signals[id].include?(signal)
  end

  def load_candidates
    return [] if @signals.empty?

    locations.where(id: @signals.keys).order(:id).map do |location|
      Candidate.new(
        id: location.id,
        display_name: location.display_name_for_directory,
        status: location.status,
        signals: @signals[location.id].sort
      )
    end
  end
end
