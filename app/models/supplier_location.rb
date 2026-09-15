class SupplierLocation < ApplicationRecord
  STATUSES = %w[active inactive].freeze
  UNIT_SEPARATOR = "\u001F"

  belongs_to :agency
  belongs_to :supplier

  enum :status, STATUSES.index_by(&:itself), validate: true, default: "active"

  attr_readonly :agency_id, :supplier_id

  normalizes :name, :timezone, :address_line_1, :address_line_2, :address_locality,
    :address_region, :address_postal_code, :address_country_code, :phone_number,
    :phone_normalized_number, :phone_extension, :phone_country_code,
    with: ->(value) { value.to_s.strip.presence }

  validates :name, presence: true, length: { maximum: 160 }
  validates :address_country_code, :phone_country_code,
    format: { with: /\A[A-Z]{2}\z/ }, allow_nil: true
  validate :timezone_is_iana
  validate :postal_shape
  validate :phone_shape
  validate :address_rejects_unit_separator
  validate :accepted_countries

  scope :ordered_for_directory, -> { order(Arel.sql("lower(name) ASC"), :id) }

  def display_name_for_directory
    name
  end

  def has_postal_address?
    [ address_line_1, address_line_2, address_locality, address_region, address_postal_code, address_country_code ]
      .any?(&:present?)
  end

  def has_phone?
    [ phone_number, phone_normalized_number, phone_extension, phone_country_code ].any?(&:present?)
  end

  private

  def timezone_is_iana
    return if timezone.blank?

    TZInfo::Timezone.get(timezone)
  rescue TZInfo::InvalidTimezoneIdentifier
    errors.add(:timezone, "is not a recognized IANA timezone")
  end

  def postal_shape
    return unless has_postal_address?

    errors.add(:address_line_1, "can't be blank") if address_line_1.blank?
    errors.add(:address_country_code, "can't be blank") if address_country_code.blank?
  end

  def phone_shape
    return unless has_phone?

    errors.add(:phone_number, "can't be blank") if phone_number.blank?
    errors.add(:phone_normalized_number, "can't be blank") if phone_normalized_number.blank?
    errors.add(:phone_country_code, "can't be blank") if phone_country_code.blank?
  end

  def address_rejects_unit_separator
    %i[address_line_1 address_line_2 address_locality address_region address_postal_code].each do |attribute|
      value = public_send(attribute)
      next if value.blank? || !value.include?(UNIT_SEPARATOR)

      errors.add(attribute, "contains an invalid control character")
    end
  end

  def accepted_countries
    if address_country_code.present? && !CountryCode.accepted?(address_country_code)
      errors.add(:address_country_code, "is not an accepted country")
    end
    if phone_country_code.present? && !CountryCode.accepted?(phone_country_code)
      errors.add(:phone_country_code, "is not an accepted country")
    end
  end
end
