# frozen_string_literal: true

class SupplierCommitment < ApplicationRecord
  include AppendOnlyRecord

  COMMITMENT_TYPES = %w[quantity monetary quantity_and_monetary].freeze
  QUANTITY_BASES = SupplierCommitmentTriggerDefinition::QUANTITY_BASES
  OPENING_KINDS = %w[confirmation_trigger deadline_requirement].freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :supplier_arrangement_activation, optional: true
  belongs_to :supplier_commitment_trigger_definition, optional: true
  belongs_to :supplier_confirmation, optional: true
  belongs_to :supplier_deadline_occurrence, optional: true
  belongs_to :supplier_deadline_commitment_definition_line, optional: true
  belongs_to :committed_supplier, class_name: "Supplier"
  belongs_to :arrangement_item, optional: true
  belongs_to :service_occurrence, optional: true
  belongs_to :supplier_resource, optional: true
  belongs_to :capacity_pool, optional: true
  belongs_to :supplier_cost_source, optional: true
  belongs_to :supplier_reservation, optional: true
  belongs_to :supplier_reservation_revision, optional: true
  belongs_to :supplier_reservation_scope, optional: true
  belongs_to :supplier_reservation_event, optional: true
  belongs_to :actor, class_name: "AgencyUser"
  belongs_to :agency_command_idempotency_key, optional: true

  has_many :supplier_commitment_dispositions, dependent: :restrict_with_exception
  has_many :supplier_commitment_reopenings, dependent: :restrict_with_exception
  has_many :supplier_commitment_evidence_coverage_members, dependent: :restrict_with_exception

  enum :commitment_type, COMMITMENT_TYPES.index_by(&:itself), validate: true
  enum :quantity_basis, QUANTITY_BASES.index_by(&:itself), validate: { allow_nil: true }
  enum :opening_kind, OPENING_KINDS.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id

  monetize :amount_minor_units, as: :amount, with_model_currency: :currency, allow_nil: true

  validates :description, :calculation_snapshot, :opened_at, presence: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :amount_minor_units,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  def current_disposition
    if association(:supplier_commitment_dispositions).loaded?
      current_from_preloaded_dispositions
    else
      supplier_commitment_dispositions
        .left_outer_joins(:supplier_commitment_reopening)
        .where(supplier_commitment_reopenings: { id: nil })
        .order(:recorded_at, :id)
        .last
    end
  end

  def open_state?
    current_disposition.nil?
  end

  def disposition_outcome
    current_disposition&.outcome
  end

  def self.with_current_disposition_state
    includes(supplier_commitment_dispositions: :supplier_commitment_reopening)
  end

  private

  def current_from_preloaded_dispositions
    supplier_commitment_dispositions
      .reject { |disposition| disposition_reopened_from_preload?(disposition) }
      .max_by { |disposition| [ disposition.recorded_at, disposition.id ] }
  end

  def disposition_reopened_from_preload?(disposition)
    if disposition.association(:supplier_commitment_reopening).loaded?
      disposition.supplier_commitment_reopening.present?
    else
      disposition.reopened?
    end
  end
end
