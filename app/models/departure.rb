class Departure < ApplicationRecord
  SALES_STATUSES = %w[draft ready_to_sell].freeze
  OPERATING_DECISIONS = %w[undecided proceed postpone cancel].freeze
  COMPLETION_STATUSES = %w[active departed cancelled superseded].freeze
  # DEP-04 summary labels, in the order the spec's table applies them.
  # Reconciled arrives with reconciliation (step 11); Sales paused is not in
  # Slice 1 (D-79).
  SUMMARY_LABELS = {
    "departed" => "Departed",
    "cancelled" => "Cancelled",
    "superseded" => "Superseded",
    "cancelling" => "Cancelling",
    "postponed" => "Postponed",
    "on_sale" => "On sale",
    "not_on_sale" => "Not on sale"
  }.freeze
  REFERENCE_FORMAT = /\ADEP-[0-9]{4,}\z/
  NAME_LIMIT = 160
  DESCRIPTION_LIMIT = 2_000

  belongs_to :agency
  has_many :decisions, -> { order(decided_at: :desc, id: :desc) },
    class_name: "DepartureDecision", inverse_of: :departure, dependent: :restrict_with_exception
  has_many :supplier_arrangements, -> { order(:created_at) }, inverse_of: :departure, dependent: :restrict_with_exception
  has_many :team_members, -> { order(default_task_owner: :desc, created_at: :asc) },
    class_name: "DepartureTeamMember", inverse_of: :departure, dependent: :restrict_with_exception

  enum :sales_status, SALES_STATUSES.index_by(&:itself), validate: true, default: "draft", prefix: :sales
  enum :operating_decision, OPERATING_DECISIONS.index_by(&:itself), validate: true, default: "undecided", prefix: :decision
  enum :completion_status, COMPLETION_STATUSES.index_by(&:itself), validate: true, default: "active", prefix: :completion

  attr_readonly :agency_id
  attr_accessor :reason

  normalizes :name, with: ->(value) { value.to_s.strip }
  normalizes :description, :time_zone, with: ->(value) { value.to_s.strip.presence }
  normalizes :operating_currency, with: ->(value) { value.to_s.strip.upcase.presence }

  validates :name, presence: true, length: { maximum: NAME_LIMIT }
  validates :description, length: { maximum: DESCRIPTION_LIMIT }, allow_nil: true
  validates :departure_reference, presence: true, format: { with: REFERENCE_FORMAT }
  validates :operating_currency, format: { with: Agency::CURRENCY_FORMAT }, allow_nil: true
  validates :hold_duration_days, numericality: { only_integer: true, greater_than_or_equal_to: 1 }, allow_nil: true
  validates :installment_buffer_days, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :dates_are_paired_and_ordered
  validate :timezone_is_iana
  validate :currency_is_known
  validate :ready_to_sell_completeness, if: :sales_ready_to_sell?

  scope :ordered_for_index, -> {
    order(Arel.sql("starts_on ASC NULLS LAST, name_search_key ASC, id ASC"))
  }

  # DEP-05: new holds and bookings are allowed only while this is true.
  scope :on_sale, -> {
    where(sales_status: "ready_to_sell", operating_decision: %w[undecided proceed], completion_status: "active")
  }

  # Column conditions for each #summary_label, so a label filter can use the
  # statuses index.
  SUMMARY_LABEL_CONDITIONS = {
    "departed" => { completion_status: "departed" },
    "cancelled" => { completion_status: "cancelled" },
    "superseded" => { completion_status: "superseded" },
    "cancelling" => { completion_status: "active", operating_decision: "cancel" },
    "postponed" => { completion_status: "active", operating_decision: "postpone" },
    "on_sale" => { completion_status: "active", operating_decision: %w[undecided proceed], sales_status: "ready_to_sell" },
    "not_on_sale" => { completion_status: "active", operating_decision: %w[undecided proceed], sales_status: "draft" }
  }.freeze

  scope :with_summary_label, ->(label) { where(SUMMARY_LABEL_CONDITIONS.fetch(label.to_s)) }

  def summary_label
    return completion_status unless completion_active?
    return "cancelling" if decision_cancel?
    return "postponed" if decision_postpone?

    sales_ready_to_sell? ? "on_sale" : "not_on_sale"
  end

  def summary_label_text
    SUMMARY_LABELS.fetch(summary_label)
  end

  def on_sale?
    sales_ready_to_sell? && (decision_undecided? || decision_proceed?) && completion_active?
  end

  def draft?
    sales_draft?
  end

  def ready_to_sell?
    sales_ready_to_sell?
  end

  def departed?
    completion_departed?
  end

  # The override if staff entered one, else the agency default (SET-14).
  def effective_hold_duration_days
    hold_duration_days || agency.hold_duration_days
  end

  def effective_installment_buffer_days
    installment_buffer_days || agency.installment_buffer_days
  end

  def default_task_owner
    team_members.find(&:default_task_owner)&.agency_user
  end

  def display_reference
    departure_reference
  end

  def schedule_label
    return "Dates not set" if starts_on.blank? || ends_on.blank?

    "#{starts_on.to_fs(:long)} – #{ends_on.to_fs(:long)}"
  end

  def ready_to_sell_blockers
    blockers = []
    blockers << "Enter a name." if name.blank?
    blockers.concat(schedule_blockers)
    blockers.concat(operating_context_blockers)
    blockers
  end

  def ready_to_sell_complete?
    ready_to_sell_blockers.empty?
  end

  def local_date(at:)
    at.in_time_zone(time_zone).to_date
  end

  def eligible_to_depart?(at:)
    ready_to_sell? && completion_active? && starts_on.present? && time_zone.present? && starts_on <= local_date(at:)
  end

  def self.eligible_to_depart_relation(at:)
    joins(:agency)
      .where(agencies: { status: "active" })
      .where(sales_status: "ready_to_sell", completion_status: "active")
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

    Money::Currency.new(operating_currency)
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

  def ready_to_sell_completeness
    errors.add(:starts_on, "can't be blank") if starts_on.blank?
    errors.add(:ends_on, "can't be blank") if ends_on.blank?
    errors.add(:time_zone, "can't be blank") if time_zone.blank?
    errors.add(:operating_currency, "can't be blank") if operating_currency.blank?
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

    Money::Currency.new(operating_currency)
    true
  rescue Money::Currency::UnknownCurrency
    false
  end
end
