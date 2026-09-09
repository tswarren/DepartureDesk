class SupplierDeadline < ApplicationRecord
  STATUSES = %w[open completed waived cancelled].freeze

  belongs_to :agency
  belongs_to :office
  belongs_to :departure
  belongs_to :arrangement, class_name: "SupplierArrangement", inverse_of: :supplier_deadlines
  belongs_to :source_deposit_requirement, class_name: "SupplierDepositRequirement", optional: true, inverse_of: :supplier_deadlines
  belongs_to :source_clause, class_name: "SupplierClause", optional: true, inverse_of: :supplier_deadlines
  belongs_to :created_by_membership, class_name: "AgencyMembership", inverse_of: false
  belongs_to :rescheduled_by_membership, class_name: "AgencyMembership", optional: true, inverse_of: false
  belongs_to :status_changed_by_membership, class_name: "AgencyMembership", inverse_of: false

  enum :status, STATUSES.index_by(&:itself), validate: true

  attr_readonly :agency_id, :office_id, :departure_id, :arrangement_id, :source_deposit_requirement_id, :source_clause_id, :created_by_membership_id

  normalizes :name, :reschedule_reason, :status_reason, with: ->(value) { value&.strip.presence }

  validates :name, :original_due_on, :due_on, :status_changed_at, presence: true
  validate :exactly_one_source
  validate :same_scope
  validate :reschedule_metadata
  validate :status_metadata

  private

  def same_scope
    expected = [ agency_id, office_id, departure_id, arrangement_id ]
    if source_deposit_requirement && [ source_deposit_requirement.agency_id, source_deposit_requirement.office_id, source_deposit_requirement.departure_id, source_deposit_requirement.arrangement_id ] != expected
      errors.add(:source_deposit_requirement, "must belong to the same arrangement")
    end
    if source_clause && [ source_clause.agency_id, source_clause.office_id, source_clause.departure_id, source_clause.arrangement_id ] != expected
      errors.add(:source_clause, "must belong to the same arrangement")
    end
  end

  def exactly_one_source
    return if [ source_deposit_requirement_id.present?, source_clause_id.present? ].one?

    errors.add(:base, "Deadline must reference exactly one source")
  end

  def reschedule_metadata
    changed = rescheduled_at.present? || rescheduled_by_membership_id.present? || reschedule_reason.present?
    return unless changed
    return if rescheduled_at.present? && rescheduled_by_membership_id.present? && reschedule_reason.present?

    errors.add(:reschedule_reason, "must include reason, actor, and timestamp")
  end

  def status_metadata
    if open?
      errors.add(:status_reason, "must be blank while open") if status_reason.present?
    elsif status_reason.blank?
      errors.add(:status_reason, "is required")
    end
  end
end
