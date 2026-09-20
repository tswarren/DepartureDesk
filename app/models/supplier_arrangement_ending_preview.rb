# frozen_string_literal: true

class SupplierArrangementEndingPreview < ApplicationRecord
  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :actor, class_name: "AgencyUser"
  belongs_to :replacement_arrangement, class_name: "SupplierArrangement", optional: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id

  def expired?(at: Time.current)
    expires_at <= at
  end

  def matches_token?(raw_token)
    return false if raw_token.blank?

    ActiveSupport::SecurityUtils.secure_compare(
      token_digest,
      Digest::SHA256.hexdigest(raw_token.to_s)
    )
  end
end
