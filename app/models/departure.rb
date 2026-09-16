class Departure < ApplicationRecord
  STATUSES = %w[draft active departed].freeze
  REFERENCE_FORMAT = /\AD-[0-9]{6}\z/
  NAME_LIMIT = 160
  DESCRIPTION_LIMIT = 2_000

  belongs_to :agency
  belongs_to :responsible_office, class_name: "Office", optional: true
  belongs_to :responsible_agency_user, class_name: "AgencyUser", optional: true

  enum :status, STATUSES.index_by(&:itself), validate: true, default: "draft"

  attr_readonly :agency_id
  attr_accessor :reason

  normalizes :name, with: ->(value) { value.to_s.strip }
  normalizes :description, :time_zone, with: ->(value) { value.to_s.strip.presence }
  normalizes :operating_currency, with: ->(value) { value.to_s.strip.upcase.presence }

  validates :name, presence: true, length: { maximum: NAME_LIMIT }
  validates :description, length: { maximum: DESCRIPTION_LIMIT }, allow_nil: true
  validates :departure_reference, format: { with: REFERENCE_FORMAT }, allow_nil: true
  validates :operating_currency, format: { with: Agency::CURRENCY_FORMAT }, allow_nil: true
  validate :dates_are_paired_and_ordered
  validate :timezone_is_iana
  validate :currency_is_known

  scope :ordered_for_index, -> {
    order(Arel.sql("starts_on ASC NULLS LAST, name_search_key ASC, id ASC"))
  }

  def display_reference
    departure_reference.presence || "Draft"
  end

  def schedule_label
    return "Dates not set" if starts_on.blank? || ends_on.blank?

    "#{starts_on.to_fs(:long)} – #{ends_on.to_fs(:long)}"
  end

  def activation_blockers
    blockers = []
    blockers << "Enter a name." if name.blank?
    blockers.concat(schedule_blockers)
    blockers.concat(operating_context_blockers)
    blockers.concat(responsibility_blockers)
    blockers
  end

  def ready_to_activate?
    activation_blockers.empty?
  end

  private

  def dates_are_paired_and_ordered
    if starts_on.blank? ^ ends_on.blank?
      errors.add(:base, "Enter both a start date and an end date, or leave both blank.")
      return
    end
    return if starts_on.blank? || ends_on.blank?
    return if starts_on <= ends_on

    errors.add(:ends_on, "must be on or after the start date")
  end

  def timezone_is_iana
    return if time_zone.blank?

    TZInfo::Timezone.get(time_zone)
  rescue TZInfo::InvalidTimezoneIdentifier
    errors.add(:time_zone, "is not a recognized IANA timezone")
  end

  def currency_is_known
    return if operating_currency.blank?

    Money::Currency.find(operating_currency)
  rescue Money::Currency::UnknownCurrency
    errors.add(:operating_currency, "is not a supported currency")
  end

  def schedule_blockers
    blockers = []
    if starts_on.blank? || ends_on.blank?
      blockers << "Enter a start date and an end date."
    elsif starts_on > ends_on
      blockers << "End date must be on or after the start date."
    end
    blockers
  end

  def operating_context_blockers
    blockers = []
    if time_zone.blank?
      blockers << "Enter a recognized time zone."
    else
      TZInfo::Timezone.get(time_zone)
    end
    if operating_currency.blank?
      blockers << "Enter a supported operating currency."
    else
      Money::Currency.find(operating_currency)
    end
    blockers
  rescue TZInfo::InvalidTimezoneIdentifier
    blockers << "Enter a recognized time zone."
    blockers
  rescue Money::Currency::UnknownCurrency
    blockers << "Enter a supported operating currency."
    blockers
  end

  def responsibility_blockers
    blockers = []
    if responsible_office.blank? || !responsible_office.active?
      blockers << "Choose an active responsible office."
    end
    if responsible_agency_user.blank? || !responsible_agency_user.active?
      blockers << "Choose an active responsible agency user."
    end
    blockers
  end
end
