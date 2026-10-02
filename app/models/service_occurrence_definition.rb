class ServiceOccurrenceDefinition < ApplicationRecord
  include ExactVersionCopyLineage
  include DraftVersionDefinition
  include LodgingConfirmationFreeze::Model
  include TransportationConfirmationFreeze::Model
  NAME_LIMIT = 160
  DESCRIPTION_LIMIT = 2_000
  PORT_NAME_LIMIT = 160

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :arrangement_item
  belongs_to :service_occurrence
  belongs_to :service_provider, class_name: "Supplier", optional: true
  has_many :service_offer_source_bindings, dependent: :restrict_with_exception

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :arrangement_item_id, :service_occurrence_id

  normalizes :name, with: ->(value) { value.to_s.strip }
  normalizes :description, :time_zone, :departure_port_name, :return_port_name,
    :origin_name, :destination_name,
    with: ->(value) { value.to_s.strip.presence }

  validates :name, presence: true, length: { maximum: NAME_LIMIT }
  validates :description, length: { maximum: DESCRIPTION_LIMIT }, allow_nil: true
  validates :departure_port_name, :return_port_name, :origin_name, :destination_name,
    length: { maximum: PORT_NAME_LIMIT }, allow_nil: true
  validates :starts_on, :ends_on, :time_zone, presence: true
  validate :date_range_is_ordered
  validate :same_day_local_times_are_ordered
  validate :timezone_is_iana

  def self.human_attribute_name(attribute, options = {})
    case attribute.to_s
    when "starts_on" then "Start date"
    when "ends_on" then "End date"
    else super
    end
  end

  private

  def date_range_is_ordered
    return if starts_on.blank? || ends_on.blank?
    return if starts_on <= ends_on

    errors.add(:ends_on, "must be on or after the start date")
  end

  def same_day_local_times_are_ordered
    return if starts_on.blank? || ends_on.blank? || starts_on != ends_on
    return if starts_at_local.blank? || ends_at_local.blank?
    return if starts_at_local <= ends_at_local

    errors.add(:ends_at_local, "must be at or after the start time on the same day")
  end

  def timezone_is_iana
    return if time_zone.blank?

    TZInfo::Timezone.get(time_zone)
  rescue TZInfo::InvalidTimezoneIdentifier
    errors.add(:time_zone, "is not a recognized IANA timezone")
  end
end
