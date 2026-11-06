# A supplier deadline on an arrangement (SUP-22 to SUP-25). It keeps the
# supplier's local date, optional time and zone, and the instant it
# resolves to, stored when recorded (SET-10). An actionable deadline has a
# task; it prompts staff only and never acts on its own (SUP-25).
class SupplierDeadline < ApplicationRecord
  TYPES = %w[option_release deposit_payment names_submission rooming_list ticketing final_count cancellation_tier_cutoff other].freeze
  # SUP-22: a cancellation-tier cutoff is informational by default.
  INFORMATIONAL_BY_DEFAULT = %w[cancellation_tier_cutoff].freeze
  DESCRIPTION_LIMIT = 200

  belongs_to :agency
  belongs_to :supplier_arrangement
  belongs_to :inventory_group, optional: true
  has_one :task, dependent: :restrict_with_exception

  enum :deadline_type, TYPES.index_by(&:itself), validate: true

  attr_readonly :agency_id, :supplier_arrangement_id

  normalizes :description, with: ->(value) { value.to_s.squish }

  validates :description, presence: true, length: { maximum: DESCRIPTION_LIMIT }
  validates :actionable, inclusion: { in: [ true, false ] }
  validates :due_on, :time_zone, :resolved_at, presence: true
  validate :time_zone_is_iana
  validate :group_of_arrangement

  scope :ordered, -> { order(:resolved_at, :created_at) }

  def self.default_actionable?(deadline_type) = !INFORMATIONAL_BY_DEFAULT.include?(deadline_type.to_s)

  # SET-10, SUP-24: the stated time in the stated zone, or 11:59 p.m. agency
  # local time on a date-only deadline.
  def self.resolve(due_on:, due_at_time:, time_zone:)
    return AgencyLocalTime.end_of_date(due_on, time_zone) if due_at_time.nil?

    ActiveSupport::TimeZone[time_zone].local(due_on.year, due_on.month, due_on.day, due_at_time.hour, due_at_time.min)
  end

  private

  def time_zone_is_iana
    return if time_zone.blank?

    TZInfo::Timezone.get(time_zone)
  rescue TZInfo::InvalidTimezoneIdentifier
    errors.add(:time_zone, "is not a recognized IANA timezone")
  end

  def group_of_arrangement
    return unless inventory_group && supplier_arrangement

    errors.add(:inventory_group, "must belong to the arrangement") if inventory_group.supplier_arrangement_id != supplier_arrangement_id
  end
end
