# frozen_string_literal: true

class SupplierAgreementReferenceAbsence < ApplicationRecord
  include ExactVersionCopyLineage
  include DraftVersionDefinition

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :arrangement_item, optional: true
  belongs_to :recorded_by, class_name: "AgencyUser"

  enum :kind, SupplierAgreementReference::KINDS.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :arrangement_item_id, :kind

  validates :recorded_at, presence: true
  validates :arrangement_item, presence: true, if: :item_kind?
  validates :kind, uniqueness: { scope: [ :supplier_arrangement_version_id, :arrangement_item_id ] }
  validate :version_must_be_unconfirmed_for_absence_mutation
  before_destroy :reject_confirmed_absence_destroy

  private

  def item_kind?
    SupplierAgreementReference::ITEM_KINDS.include?(kind)
  end

  def version_must_be_unconfirmed_for_absence_mutation
    return unless confirmed_version?

    errors.add(:base, "Agreement references are immutable after Supplier confirmation")
  end

  def reject_confirmed_absence_destroy
    return unless confirmed_version?

    errors.add(:base, "Agreement references are immutable after Supplier confirmation")
    throw :abort
  end

  def confirmed_version?
    supplier_arrangement_version_id.present? &&
      SupplierConfirmation.exists?(supplier_arrangement_version_id: supplier_arrangement_version_id)
  end
end
