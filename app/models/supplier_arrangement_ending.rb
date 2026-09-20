# frozen_string_literal: true

class SupplierArrangementEnding < ApplicationRecord
  include AppendOnlyRecord

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :supplier_arrangement_ending_preview
  belongs_to :replacement_arrangement, class_name: "SupplierArrangement", optional: true
  belongs_to :actor, class_name: "AgencyUser"
  belongs_to :agency_command_idempotency_key, optional: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id
end
