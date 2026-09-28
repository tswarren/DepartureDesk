# frozen_string_literal: true

module CruiseCompositionHelper
  CRUISE_INVENTORY_MODE_LABELS = {
    "block" => "Fixed block / held cabins",
    "allotment" => "Replenishable allotment",
    "on_request" => "Available on request",
    "externally_managed" => "Managed in Supplier system"
  }.freeze

  def cruise_recommended_next_path(action)
    case action.key
    when :add_cabins
      new_departure_arrangement_cruise_cabin_category_path(@departure, @supplier_arrangement)
    when :add_rates, :review_contracted_rates
      if action.advanced
        departure_arrangement_item_costs_workspace_path(@departure, @supplier_arrangement, @shape.item)
      else
        departure_arrangement_cruise_cabin_category_supplier_rates_path(
          @departure, @supplier_arrangement, action.resource_id
        )
      end
    when :record_agreement
      departure_arrangement_cruise_agreement_path(@departure, @supplier_arrangement)
    when :record_initial_deposit, :record_hard_stop, :record_final_payment
      departure_arrangement_cruise_deposits_and_deadlines_path(@departure, @supplier_arrangement)
    when :resolve_blocker, :review_activation
      departure_arrangement_activation_path(@departure, @supplier_arrangement)
    end
  end

  def cruise_sailing_date_range(occurrence)
    return nil if occurrence.nil?

    start_on = occurrence.starts_on
    end_on = occurrence.ends_on
    if start_on.year == end_on.year && start_on.month == end_on.month
      "#{start_on.strftime("%b %-d")}–#{end_on.strftime("%-d, %Y")}"
    elsif start_on.year == end_on.year
      "#{start_on.strftime("%b %-d")}–#{end_on.strftime("%b %-d, %Y")}"
    else
      "#{start_on.strftime("%b %-d, %Y")}–#{end_on.strftime("%b %-d, %Y")}"
    end
  end

  def cruise_agreement_requirements_status(summary)
    agreement = summary.sections.find { |section| section.key == "agreement" }
    requirements = summary.sections.find { |section| section.key == "requirements" }
    return requirements.status_label if agreement.status_label.start_with?("Confirmed")

    agreement.status_label
  end

  def cruise_rate_posture_label(posture)
    {
      missing: "Not entered",
      estimated: "Estimated",
      contracted_working: "Contracted, not ready",
      contracted_ready: "Contracted",
      working: "In progress",
      unsupported: "Advanced"
    }.fetch(posture, posture.to_s.tr("_", " "))
  end

  def cruise_inventory_mode_label(mode)
    CRUISE_INVENTORY_MODE_LABELS.fetch(mode.to_s) { mode.to_s.tr("_", " ").titleize }
  end

  def cruise_inventory_mode_options
    CRUISE_INVENTORY_MODE_LABELS.map { |value, label| [ label, value ] }
  end

  def cruise_cabin_batch_inventory_options
    [
      [ "Fixed block", "block" ],
      [ "On request", "on_request" ],
      [ "Externally managed", "externally_managed" ]
    ]
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
    confirmed = version.supplier_confirmations.any?
    if version.draft? && !confirmed && definition.copied_from && cruise_benefit_wording_differs?(definition)
      "Proposed amendment awaiting confirmation. This is not the governing agreement."
    elsif version.draft? && !confirmed
      "Draft wording for this version. The group agreement is not Supplier-confirmed."
    elsif version.activated?
      "Frozen wording for this governing version."
    elsif confirmed
      "Recorded wording for this Supplier-confirmed revision."
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
