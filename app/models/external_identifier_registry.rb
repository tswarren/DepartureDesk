class ExternalIdentifierRegistry
  Type = Data.define(
    :code,
    :owner,
    :label,
    :issuer_required,
    :office_context_allowed,
    :uniqueness,
    :normalization_version
  )

  TYPES = [
    Type.new("legacy_party_id", :party, "Legacy party ID", false, false, :advisory, 1),
    Type.new("legacy_client_id", :client_profile, "Legacy client ID", true, false, :per_issuer, 1),
    Type.new("external_crm_id", :client_profile, "External CRM ID", true, false, :per_issuer, 1),
    Type.new("supplier_account_number", :supplier_profile, "Supplier account number", true, false, :per_issuer, 1),
    Type.new("supplier_portal_id", :supplier_profile, "Supplier portal ID", true, false, :per_issuer, 1),
    Type.new("industry_supplier_code", :supplier_profile, "Industry supplier code", true, false, :per_issuer, 1)
  ].freeze

  INDEX_BY_CODE = TYPES.index_by(&:code).freeze
  CODES = TYPES.map(&:code).freeze
  OWNERS = {
    party: :party_id,
    client_profile: :client_profile_id,
    supplier_profile: :supplier_profile_id
  }.freeze

  def self.type!(code)
    INDEX_BY_CODE.fetch(code.to_s) do
      raise ArgumentError, "Unknown identifier type."
    end
  end

  def self.known?(code)
    INDEX_BY_CODE.key?(code.to_s)
  end

  def self.codes
    CODES
  end

  def self.contractually_unique_codes
    TYPES.select { |type| type.uniqueness == :per_issuer }.map(&:code)
  end

  def self.issuer_required_codes
    TYPES.select(&:issuer_required).map(&:code)
  end

  def self.owner_column(code)
    OWNERS.fetch(type!(code).owner)
  end

  def self.types_for_owner(owner)
    TYPES.select { |type| type.owner == owner }
  end

  def self.normalize(code, original_value)
    type!(code)
    original_value.to_s.strip.gsub(/[[:space:]]+/, " ")
  end
end
