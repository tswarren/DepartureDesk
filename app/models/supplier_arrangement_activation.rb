class SupplierArrangementActivation < ApplicationRecord
  include AppendOnlyRecord

  ACTIVATION_KINDS = %w[first successor].freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :predecessor_version, class_name: "SupplierArrangementVersion", optional: true
  belongs_to :predecessor_activation, class_name: "SupplierArrangementActivation", optional: true
  belongs_to :supplier_confirmation
  belongs_to :actor, class_name: "AgencyUser"

  has_many :cost_selections,
    class_name: "SupplierArrangementActivationCostSelection",
    dependent: :restrict_with_exception
  has_many :capacity_entries,
    class_name: "SupplierArrangementActivationCapacityEntry",
    dependent: :restrict_with_exception
  has_many :supplier_commitments, dependent: :restrict_with_exception

  enum :activation_kind, ACTIVATION_KINDS.index_by(&:itself),
    validate: true, scopes: false, instance_methods: false

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id

  validates :activated_at, :coverage_attestation_version, :coverage_fingerprint, presence: true
  validate :predecessor_matches_kind

  private

  def predecessor_matches_kind
    present = predecessor_version_id.present? && predecessor_activation_id.present?
    errors.add(:base, "Predecessor must match activation kind") unless
      (activation_kind == "successor") == present
  end
end
