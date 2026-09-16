class ServiceOccurrenceDefinition < ApplicationRecord
  NAME_LIMIT = 160
  DESCRIPTION_LIMIT = 2_000

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :arrangement_item
  belongs_to :service_occurrence
  belongs_to :service_provider, class_name: "Supplier", optional: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :arrangement_item_id, :service_occurrence_id

  normalizes :name, with: ->(value) { value.to_s.strip }
  normalizes :description, :time_zone, with: ->(value) { value.to_s.strip.presence }

  validates :name, presence: true, length: { maximum: NAME_LIMIT }
  validates :description, length: { maximum: DESCRIPTION_LIMIT }, allow_nil: true
  validates :starts_on, :ends_on, :time_zone, presence: true
  validate :date_range_is_ordered
  validate :local_times_are_paired
  validate :timezone_is_iana

  private

  def date_range_is_ordered
    return if starts_on.blank? || ends_on.blank?
    return if starts_on <= ends_on

    errors.add(:ends_on, "must be on or after the start date")
  end

  def local_times_are_paired
    return unless starts_at_local.blank? ^ ends_at_local.blank?

    errors.add(:base, "Enter both a local start time and local end time, or leave both blank.")
  end

  def timezone_is_iana
    return if time_zone.blank?

    TZInfo::Timezone.get(time_zone)
  rescue TZInfo::InvalidTimezoneIdentifier
    errors.add(:time_zone, "is not a recognized IANA timezone")
  end
end
