# frozen_string_literal: true

class SupplierDepositRefundClarification < ApplicationRecord
  include ExactVersionCopyLineage
  include DraftVersionDefinition

  PARTIES = %w[agency].freeze
  WORDING_LIMIT = 2_000

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :arrangement_item
  belongs_to :recorded_by, class_name: "AgencyUser"

  enum :payer, PARTIES.index_by(&:itself), validate: true, prefix: true
  enum :recipient, PARTIES.index_by(&:itself), validate: true, prefix: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :arrangement_item_id

  normalizes :original_wording, :governing_wording, with: ->(value) { value.to_s.strip }
  normalizes :evidence_note, with: ->(value) { value.to_s.strip.presence }

  validates :original_wording, :governing_wording, presence: true, length: { maximum: WORDING_LIMIT }
  validates :evidence_note, length: { maximum: WORDING_LIMIT }, allow_nil: true
  validates :refund_due_on, :recorded_at, presence: true
  validates :arrangement_item_id, uniqueness: { scope: :supplier_arrangement_version_id }
end
