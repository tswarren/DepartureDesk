class Departure < ApplicationRecord
  STATUSES = %w[
    draft
    planning
    cancelled
  ].freeze
  NONTERMINAL_STATUSES = %w[
    draft
    planning
  ].freeze
  REFERENCE_FORMAT = /\AD-[0-9]{6,}\z/
  CURRENCY_FORMAT = /\A[A-Z]{3}\z/

  belongs_to :agency
  belongs_to :office
  belongs_to :travel_program, optional: true
  belongs_to :created_by_membership, class_name: "AgencyMembership", inverse_of: false
  belongs_to :status_changed_by_membership, class_name: "AgencyMembership", inverse_of: false
  has_many :team_assignments,
    class_name: "DepartureTeamAssignment",
    inverse_of: :departure,
    dependent: :restrict_with_exception
  has_many :party_role_assignments,
    class_name: "DeparturePartyRoleAssignment",
    inverse_of: :departure,
    dependent: :restrict_with_exception
  has_many :supplier_arrangements,
    inverse_of: :departure,
    dependent: :restrict_with_exception

  enum :status, STATUSES.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_reference, :creation_idempotency_key, :created_by_membership_id

  normalizes :name, with: ->(value) { value&.strip }
  normalizes :description, :client_facing_description, :primary_destination, :status_reason, with: ->(value) { value&.strip.presence }
  normalizes :default_currency, with: ->(value) { value&.strip&.upcase }

  validates :name, presence: true
  validates :departure_reference, presence: true, format: { with: REFERENCE_FORMAT }
  validates :creation_idempotency_key, presence: true
  validates :start_date, :end_date, :status_changed_at, presence: true
  validates :default_currency, presence: true, format: { with: CURRENCY_FORMAT }
  validate :currency_is_known
  validate :date_order
  validate :sales_date_order
  validate :owning_office_projection
  validate :program_projection
  validate :status_metadata
  validate :same_agency_participants

  scope :nonterminal, -> { where(status: NONTERMINAL_STATUSES) }
  scope :terminal, -> { where(status: "cancelled") }

  def nonterminal?
    NONTERMINAL_STATUSES.include?(status)
  end

  def current_team_assignments
    team_assignments.current
  end

  def current_group_manager_assignment
    team_assignments.current.group_manager.first
  end

  def current_responsible_advisor_assignment
    team_assignments.current.responsible_advisor.first
  end

  def current_party_role_assignments
    party_role_assignments.current
  end

  private

  def currency_is_known
    return if default_currency.blank?

    Money::Currency.find(default_currency)
  rescue Money::Currency::UnknownCurrency
    errors.add(:default_currency, "is not a supported currency")
  end

  def date_order
    return if start_date.blank? || end_date.blank?
    return if end_date >= start_date

    errors.add(:end_date, "must be on or after the start date")
  end

  def sales_date_order
    return if sales_open_on.blank? || sales_close_on.blank?
    return if sales_close_on >= sales_open_on

    errors.add(:sales_close_on, "must be on or after the sales open date")
  end

  def owning_office_projection
    if nonterminal?
      errors.add(:owning_office_status, "must be active") unless owning_office_status == "active"
    elsif cancelled?
      errors.add(:owning_office_status, "must be blank") if owning_office_status.present?
    end
  end

  def program_projection
    if travel_program_id.blank?
      errors.add(:travel_program_status, "must be blank") if travel_program_status.present?
      return
    end

    if nonterminal?
      errors.add(:travel_program_status, "must be active") unless travel_program_status == "active"
    elsif cancelled?
      errors.add(:travel_program_status, "must be blank") if travel_program_status.present?
    end
  end

  def status_metadata
    if cancelled?
      errors.add(:status_reason, "is required") if status_reason.blank?
    elsif status_reason.present?
      errors.add(:status_reason, "must be blank until cancellation")
    end
  end

  def same_agency_participants
    if office.present? && agency_id.present? && office.agency_id != agency_id
      errors.add(:office, "must belong to the same agency")
    end
    if travel_program.present? && agency_id.present? && travel_program.agency_id != agency_id
      errors.add(:travel_program, "must belong to the same agency")
    end
  end
end
