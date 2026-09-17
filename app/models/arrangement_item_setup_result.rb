class ArrangementItemSetupResult < ApplicationRecord
  belongs_to :agency
  belongs_to :agency_command_idempotency_key
  belongs_to :arrangement_item
  belongs_to :service_occurrence, optional: true
  belongs_to :supplier_resource, optional: true

  attr_readonly :agency_id, :agency_command_idempotency_key_id,
    :arrangement_item_id, :service_occurrence_id, :supplier_resource_id

  validates :agency_command_idempotency_key_id, uniqueness: true
  validate :children_belong_to_item

  private

  def children_belong_to_item
    if service_occurrence && service_occurrence.arrangement_item_id != arrangement_item_id
      errors.add(:service_occurrence, "must belong to the setup item")
    end
    if supplier_resource && supplier_resource.arrangement_item_id != arrangement_item_id
      errors.add(:supplier_resource, "must belong to the setup item")
    end
  end
end
