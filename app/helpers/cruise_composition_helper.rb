# frozen_string_literal: true

module CruiseCompositionHelper
  CRUISE_INVENTORY_MODE_LABELS = {
    "block" => "Fixed block / held cabins",
    "allotment" => "Replenishable allotment",
    "on_request" => "Available on request",
    "externally_managed" => "Managed in Supplier system"
  }.freeze

  def cruise_inventory_mode_label(mode)
    CRUISE_INVENTORY_MODE_LABELS.fetch(mode.to_s) { mode.to_s.tr("_", " ").titleize }
  end

  def cruise_inventory_mode_options
    CRUISE_INVENTORY_MODE_LABELS.map { |value, label| [ label, value ] }
  end

  def cruise_version_status_label(version)
    return "No version" if version.nil?

    case version.status
    when "draft"
      version.version_number.to_i > 1 ? "Successor draft" : "Draft"
    when "activated" then "Governing"
    else version.status.to_s.humanize
    end
  end

  def cruise_cabin_quantity_label(pool, pool_definition)
    return "Quantity not tracked" if pool.nil? || !pool.numeric_inventory?

    quantity = pool_definition&.proposed_opening_quantity
    return "Cabin quantity not set" if quantity.blank?

    "#{quantity} #{"cabin".pluralize(quantity)}"
  end
end
