# frozen_string_literal: true

module CruiseClientTermRows
  STANDARD = {
    "cruise_fare" => { label: "Cruise fare", client_role: "base_price" },
    "nccf" => { label: "NCCF", client_role: "named_surcharge" },
    "taxes_fees" => { label: "Taxes and fees", client_role: "tax_fee" },
    "discount" => { label: "Discount", client_role: "named_discount" },
    "agency_fee" => { label: "Agency fee", client_role: "named_surcharge" },
    "single_supplement" => { label: "Single supplement", client_role: "named_surcharge", bands: %w[single] }
  }.freeze

  BANDS = %w[single first second additional].freeze
  CUSTOM_KEY = /\Acustom_[a-z0-9_]{8,64}\z/

  module_function

  def standard?(key)
    STANDARD.key?(key.to_s)
  end

  def known?(key)
    standard?(key) || key.to_s.match?(CUSTOM_KEY)
  end

  def role_for(key)
    return STANDARD.dig(key.to_s, :client_role) if standard?(key)

    key.to_s.include?("discount") ? "named_discount" : "named_surcharge"
  end

  def label_for(key)
    STANDARD.dig(key.to_s, :label) || "Surcharge"
  end

  def allowed_bands(key)
    STANDARD.dig(key.to_s, :bands) || BANDS
  end

  def mint_custom_key
    "custom_#{SecureRandom.hex(8)}"
  end
end
