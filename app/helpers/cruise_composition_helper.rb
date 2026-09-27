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

  def cruise_typed_cabin_pool?(pool, pool_definition)
    CruiseCabinCategorySupport.typed_cabin_pool?(pool, pool_definition)
  end

  def cruise_connection_status_label(status)
    {
      not_connected: "Not connected",
      decide_later: "Decide later",
      connected: "Connected",
      advanced: "Advanced"
    }.fetch(status.to_sym, "Not connected")
  end

  def cruise_cabin_quantity_label(pool, pool_definition)
    return "Quantity not tracked" unless cruise_typed_cabin_pool?(pool, pool_definition)
    return "Quantity not tracked" unless pool.numeric_inventory?

    quantity = pool_definition.proposed_opening_quantity
    return "Cabin quantity not set" if quantity.blank?

    "#{quantity} #{"cabin".pluralize(quantity)}"
  end

  def cruise_deposit_amount_shape_label(amount_shape, quantity_basis: nil)
    CruiseDepositsAndDeadlinesLanguage.amount_shape_label(amount_shape, quantity_basis:)
  end

  def cruise_deposit_amount_label(definition, currency:)
    CruiseDepositsAndDeadlinesLanguage.amount_label_for(definition, currency:)
  end

  def cruise_benefit_label(term_type)
    SupplierArrangementCommercialBenefitDefinition.label_for(term_type)
  end

  def cruise_benefit_recorded_label
    SupplierArrangementCommercialBenefitDefinition::RECORDED_LABEL
  end

  def cruise_benefit_revision_sentence(version, definition)
    if version.draft? && definition.copied_from && cruise_benefit_wording_differs?(definition)
      "Proposed amendment awaiting confirmation. This is not the governing agreement."
    elsif version.draft? && version.supplier_confirmations.none?
      "Draft wording for this version. The group agreement is not Supplier-confirmed."
    elsif version.activated?
      "Frozen wording for this governing version."
    else
      "Recorded wording for this version."
    end
  end

  def cruise_benefit_wording_differs?(definition)
    source = definition.copied_from
    definition.body != source.body || definition.source_citation != source.source_citation
  end

  def cruise_definition_status_badge(status_label)
    modifier = CruiseDepositsAndDeadlinesLanguage.status_badge_modifier(status_label)
    tag.span(status_label, class: "dd-badge dd-badge--#{modifier}")
  end
end
