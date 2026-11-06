# A supplier document kept with an arrangement (SUP-06, S-12): a quote,
# agreement, confirmation or other file. Rules are in the ADR 0019
# amendment: allowed types, size, ACC-31 access and audited removal.
class ArrangementDocument < ApplicationRecord
  KINDS = %w[quote agreement confirmation other].freeze
  CONTENT_TYPES = {
    "application/pdf" => "PDF",
    "image/png" => "PNG image",
    "image/jpeg" => "JPEG image",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document" => "Word document",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" => "Excel workbook"
  }.freeze
  OFFICE_CONTENT_TYPES = CONTENT_TYPES.keys.grep(/officedocument/).freeze
  INLINE_CONTENT_TYPES = (CONTENT_TYPES.keys - OFFICE_CONTENT_TYPES).freeze
  MAX_BYTES = 20.megabytes
  DESCRIPTION_LIMIT = 200

  belongs_to :agency
  belongs_to :supplier_arrangement
  belongs_to :uploaded_by, class_name: "AgencyUser"
  has_one_attached :file

  attr_readonly :agency_id, :supplier_arrangement_id, :uploaded_by_id, :sha256

  normalizes :description, with: ->(value) { value.to_s.squish.presence }

  validates :kind, inclusion: { in: KINDS }
  validates :description, length: { maximum: DESCRIPTION_LIMIT }, allow_nil: true
  validates :sha256, format: { with: /\A[0-9a-f]{64}\z/ }

  def office?
    file.attached? && file.content_type.in?(OFFICE_CONTENT_TYPES)
  end
end
