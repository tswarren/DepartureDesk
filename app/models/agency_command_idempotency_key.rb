class AgencyCommandIdempotencyKey < ApplicationRecord
  belongs_to :agency

  attr_readonly :agency_id, :command_name, :idempotency_key, :payload_digest,
    :result_record_type, :result_record_id

  normalizes :command_name, :idempotency_key, :payload_digest, :result_record_type,
    with: ->(value) { value.to_s.strip }

  validates :command_name, :idempotency_key, presence: true, length: { maximum: 120 }
  validates :payload_digest, presence: true, length: { maximum: 128 }
  validates :result_record_type, presence: true, length: { maximum: 120 }
  validates :result_record_id, presence: true
end
