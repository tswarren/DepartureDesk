# A supplier's arrangement for one Departure (SUP-06, SUP-07, SUP-11). One
# record, no versions (ADR 0018): Draft is edited in place; Confirm creates
# inventory; later changes are dated rows.
class SupplierArrangement < ApplicationRecord
  STATUSES = %w[draft confirmed closed cancelled].freeze
  RESERVATION_SCOPES = %w[arrangement per_unit none].freeze
  OBLIGATION_SHAPES = %w[per_unit_used committed_quantity fixed_resource_charge minimum_pickup mixed].freeze
  AVAILABILITY_PROMISES = %w[firm_block releasable_block courtesy_option on_request rate_only].freeze
  REFERENCE_FORMAT = /\AARR-[0-9]{4,}\z/
  TEXT_LIMIT = 4_000

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier
  belongs_to :payee_account, optional: true
  has_many :inventory_groups, -> { ordered }, inverse_of: :supplier_arrangement, dependent: :restrict_with_exception
  has_many :documents, -> { order(created_at: :desc) }, class_name: "ArrangementDocument", inverse_of: :supplier_arrangement, dependent: :restrict_with_exception
  has_many :rate_lines, class_name: "SupplierRateLine", inverse_of: :supplier_arrangement, dependent: :restrict_with_exception
  has_many :deadlines, -> { ordered }, class_name: "SupplierDeadline", inverse_of: :supplier_arrangement, dependent: :restrict_with_exception
  has_many :cost_lines, -> { order(:created_at) }, inverse_of: :supplier_arrangement, dependent: :restrict_with_exception
  has_many :schedule_lines, -> { order(:created_at) }, inverse_of: :supplier_arrangement, dependent: :restrict_with_exception
  has_many :trigger_events, -> { order(:occurred_on, :recorded_at) }, inverse_of: :supplier_arrangement, dependent: :restrict_with_exception
  has_many :amounts_due, -> { by_due }, class_name: "AmountDue", inverse_of: :supplier_arrangement, dependent: :restrict_with_exception

  enum :status, STATUSES.index_by(&:itself), validate: true, default: "draft"
  enum :reservation_scope, RESERVATION_SCOPES.index_by(&:itself), validate: true, prefix: :reservations
  enum :obligation_shape, OBLIGATION_SHAPES.index_by(&:itself), validate: { allow_nil: true }, prefix: :obligation
  enum :default_availability_promise, AVAILABILITY_PROMISES.index_by(&:itself), validate: true, prefix: :default_promise

  attr_readonly :agency_id, :departure_id, :supplier_id, :arrangement_reference

  normalizes :group_reference, with: ->(value) { value.to_s.strip.presence }
  normalizes :covered_services, :terms, :confirmation_note, with: ->(value) { value.to_s.gsub("\r\n", "\n").strip.presence }

  validates :arrangement_reference, format: { with: REFERENCE_FORMAT }
  validates :currency, format: { with: Agency::CURRENCY_FORMAT }
  validates :group_reference, length: { maximum: 80 }, allow_nil: true
  validates :covered_services, :terms, :confirmation_note, length: { maximum: TEXT_LIMIT }, allow_nil: true
  validate :same_agency_records

  scope :live, -> { where.not(status: "cancelled") }

  # What Confirm still needs (SUP-11 guard, plus the step 3 plan's rules).
  def confirmation_blockers
    blockers = []
    blockers << "Enter the supplier's group or confirmation reference." if group_reference.blank?
    blockers << "Choose a payee account." if payee_account_id.blank?
    blockers << "Add at least one inventory group." if inventory_groups.empty?
    inventory_groups.each { |group| blockers.concat(group.confirmation_blockers) }
    rate_lines.includes(:inventory_group).each do |line|
      next if line.inventory_group.positions_per_unit.nil? || line.guest_number.to_i <= line.inventory_group.positions_per_unit

      blockers << "Remove the guest #{line.guest_number} rate for #{line.inventory_group.label}; it has #{line.inventory_group.positions_per_unit} positions."
    end
    blockers
  end

  private

  def same_agency_records
    errors.add(:departure, "must belong to the same agency") if departure && departure.agency_id != agency_id
    errors.add(:supplier, "must belong to the same agency") if supplier && supplier.agency_id != agency_id
    errors.add(:payee_account, "must belong to the supplier") if payee_account && payee_account.supplier_id != supplier_id
  end
end
