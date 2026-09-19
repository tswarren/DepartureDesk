class Departure < ApplicationRecord
  STATUSES = %w[draft active departed].freeze
  REFERENCE_FORMAT = /\AD-[0-9]{6}\z/
  NAME_LIMIT = 160
  DESCRIPTION_LIMIT = 2_000

  belongs_to :agency
  belongs_to :responsible_office, class_name: "Office", optional: true
  belongs_to :responsible_agency_user, class_name: "AgencyUser", optional: true
  has_many :supplier_arrangements, dependent: :restrict_with_exception
  has_many :supplier_arrangement_versions, dependent: :restrict_with_exception
  has_many :arrangement_items, dependent: :restrict_with_exception
  has_many :arrangement_item_definitions, dependent: :restrict_with_exception
  has_many :service_occurrences, dependent: :restrict_with_exception
  has_many :service_occurrence_definitions, dependent: :restrict_with_exception
  has_many :supplier_resources, dependent: :restrict_with_exception
  has_many :supplier_resource_definitions, dependent: :restrict_with_exception
  has_many :supplier_cost_sources, dependent: :restrict_with_exception
  has_many :supplier_cost_definitions, dependent: :restrict_with_exception
  has_many :supplier_cost_components, dependent: :restrict_with_exception
  has_many :supplier_cost_component_bases, dependent: :restrict_with_exception
  has_many :supplier_cost_participant_categories, dependent: :restrict_with_exception
  has_many :supplier_cost_usage_assumptions, dependent: :restrict_with_exception
  has_many :supplier_cost_occupancy_profiles, dependent: :restrict_with_exception
  has_many :supplier_cost_occupancy_profile_positions, dependent: :restrict_with_exception
  has_many :supplier_arrangement_activations, dependent: :restrict_with_exception
  has_many :supplier_confirmations, dependent: :restrict_with_exception
  has_many :supplier_commitment_trigger_definitions, dependent: :restrict_with_exception
  has_many :supplier_deadline_definitions, dependent: :restrict_with_exception
  has_many :supplier_deadline_occurrences, dependent: :restrict_with_exception
  has_many :supplier_commitments, dependent: :restrict_with_exception
  has_many :supplier_issued_identifiers, dependent: :restrict_with_exception

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
  validate :non_draft_completeness, unless: :draft?

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

  def local_date(at:)
    at.in_time_zone(time_zone).to_date
  end

  def eligible_to_depart?(at:)
    active? && starts_on.present? && time_zone.present? && starts_on <= local_date(at:)
  end

  # Permanent downstream-history latch. Activation rows are append-only and
  # indexed by Departure, so this cannot drift like a mutable boolean.
  def supplier_arrangement_activation_history?
    supplier_arrangement_activations.exists?
  end

  def lifecycle_correction_allowed?(at:)
    departed? && starts_on.present? && time_zone.present? && starts_on > local_date(at:)
  end

  def self.eligible_to_depart_relation(at:)
    joins(:agency)
      .where(agencies: { status: "active" })
      .where(status: "active")
      .where.not(starts_on: nil)
      .where.not(time_zone: nil)
      .where("departures.starts_on <= (?::timestamptz AT TIME ZONE departures.time_zone)::date", at)
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

  def non_draft_completeness
    errors.add(:starts_on, "can't be blank") if starts_on.blank?
    errors.add(:ends_on, "can't be blank") if ends_on.blank?
    errors.add(:time_zone, "can't be blank") if time_zone.blank?
    errors.add(:operating_currency, "can't be blank") if operating_currency.blank?
    errors.add(:responsible_office_id, "can't be blank") if responsible_office_id.blank?
    errors.add(:responsible_agency_user_id, "can't be blank") if responsible_agency_user_id.blank?
  end

  def operating_context_blockers
    blockers = []
    blockers << "Enter a recognized time zone." unless recognized_time_zone?
    blockers << "Enter a supported operating currency." unless supported_operating_currency?
    blockers
  end

  def recognized_time_zone?
    return false if time_zone.blank?

    TZInfo::Timezone.get(time_zone)
    true
  rescue TZInfo::InvalidTimezoneIdentifier
    false
  end

  def supported_operating_currency?
    return false if operating_currency.blank?

    Money::Currency.find(operating_currency)
    true
  rescue Money::Currency::UnknownCurrency
    false
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
