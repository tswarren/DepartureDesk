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
      departure_arrangement_cruise_agreement_path(@departure, @supplier_arrangement, focus: "agreement")
    when :record_initial_deposit
      departure_arrangement_cruise_agreement_path(@departure, @supplier_arrangement, focus: "deposit-new-initial")
    when :record_hard_stop
      departure_arrangement_cruise_agreement_path(@departure, @supplier_arrangement, focus: "deadline-new-hard-stop")
    when :record_final_payment
      departure_arrangement_cruise_agreement_path(@departure, @supplier_arrangement, focus: "deadline-new-final-payment")
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

  def cruise_version_context(version)
    return if version.nil?

    if version.activated?
      {
        title: "Active · Version #{version.version_number}",
        detail: "These Supplier terms are in effect."
      }
    elsif version.draft? && version.copied_from_id.present?
      {
        title: "Draft · Version #{version.version_number}",
        detail: "Proposed changes. Version #{version.copied_from&.version_number} remains active."
      }
    elsif version.draft?
      {
        title: "Draft · Version #{version.version_number}",
        detail: nil
      }
    end
  end

  def cruise_maintenance_step_path(step)
    case step.code
    when :opening_authority_incomplete
      if step.resource_id.present?
        edit_departure_arrangement_cruise_cabin_category_path(@departure, @supplier_arrangement, step.resource_id)
      else
        departure_arrangement_cruise_path(@departure, @supplier_arrangement, anchor: "cruise-cabins")
      end
    when :cruise_contracted_rates_missing
      cruise_supplier_rate_corrective_path(step.resource_id)
    when :cruise_agreement_unconfirmed, :cruise_deposit_treatment_missing
      departure_arrangement_cruise_agreement_path(@departure, @supplier_arrangement, focus: "agreement")
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

  def cruise_setup_navigation(version: nil)
    presented = cruise_setup_presented_version(version)
    @cruise_setup_navigations ||= {}
    @cruise_setup_navigations[presented&.id] ||= CompileCruiseSetupNavigation.new(
      agency: Current.agency,
      arrangement: @supplier_arrangement,
      shape: cruise_setup_shape_for(presented),
      summary: cruise_setup_summary_for(presented)
    ).call
  end

  def cruise_setup_presented_version(version)
    return version if version
    return @supplier_arrangement_version if @supplier_arrangement_version
    return @cruise_shape.version if @cruise_shape&.version
    return @shape.version if @shape&.version

    cruise_setup_detected_shape.version
  end

  def cruise_setup_version_badge(version)
    return if version.nil?
    return "Draft · Version #{version.version_number}" if version.draft? && version.copied_from_id.present?
    return "Draft" if version.draft?
    return "Active" if version.activated?

    nil
  end

  def cruise_setup_successor_note(version)
    return unless version&.draft? && version.copied_from_id.present?

    active_number = version.copied_from&.version_number
    "Proposed changes to Active Version #{active_number}"
  end

  def cruise_setup_title(page_title)
    return page_title if page_title.present?

    shape = cruise_setup_shape_for(cruise_setup_presented_version(nil))
    if shape.compatible?
      shape.summary["ship_name"].presence || @supplier_arrangement.name
    else
      @supplier_arrangement.name
    end
  end

  def cruise_setup_subtitle(version)
    shape = cruise_setup_shape_for(version)
    contractor = @supplier_arrangement.contracting_supplier
    return [ @departure.name, contractor ? supplier_option_label(contractor) : "Supplier not set" ] unless shape.compatible?

    parts = []
    if contractor
      name = contractor.display_name_for_directory
      name = "#{name} (Inactive)" if contractor.inactive?
      parts << name
      parts << contractor.supplier_reference
    end
    duration = cruise_setup_duration(shape.occurrence_definition)
    parts << duration if duration
    date_range = cruise_sailing_date_range(shape.occurrence_definition)
    parts << date_range if date_range
    parts << shape.summary["sailing_name"].presence
    parts.compact
  end

  def cruise_setup_duration(occurrence)
    return if occurrence.nil? || occurrence.starts_on.blank? || occurrence.ends_on.blank?

    days = (occurrence.ends_on - occurrence.starts_on).to_i
    return if days <= 0

    "#{days} #{"day".pluralize(days)}"
  end

  def cruise_setup_successor_allowed?(version)
    return false unless Current.agency_user.permitted?(:manage_departures)
    return false unless @departure.active? && @supplier_arrangement.active?
    return false unless version&.activated?

    @supplier_arrangement.versions.none?(&:draft?)
  end

  def cruise_setup_area_path(area, version)
    case area.key
    when :sailing
      if version&.draft? && Current.agency_user.permitted?(:manage_departures)
        edit_departure_arrangement_cruise_sailing_path(@departure, @supplier_arrangement)
      else
        departure_arrangement_cruise_path(@departure, @supplier_arrangement, anchor: "cruise-sailing")
      end
    when :cabins
      departure_arrangement_cruise_cabin_categories_path(@departure, @supplier_arrangement)
    when :rates
      departure_arrangement_cruise_supplier_rates_path(@departure, @supplier_arrangement)
    when :agreement
      departure_arrangement_cruise_agreement_path(@departure, @supplier_arrangement)
    when :review
      departure_arrangement_cruise_activation_path(@departure, @supplier_arrangement)
    end
  end

  def cruise_setup_attention_path(item, version)
    case item.destination
    when :cabin_editor
      cruise_cabin_corrective_path(item.resource_id, version)
    when :cabin_card
      cruise_cabin_corrective_path(nil, version)
    when :supplier_rates
      if Current.agency_user.permitted?(:manage_departures)
        cruise_supplier_rate_corrective_path(item.resource_id)
      else
        departure_arrangement_cruise_path(@departure, @supplier_arrangement)
      end
    when :advanced_costs
      item_record = cruise_setup_shape_for(version).item
      if item_record && Current.agency_user.permitted?(:manage_departures)
        departure_arrangement_item_costs_workspace_path(@departure, @supplier_arrangement, item_record)
      else
        departure_arrangement_path(@departure, @supplier_arrangement)
      end
    when :agreement
      options = {}
      if item.code.in?(%i[cruise_agreement_unconfirmed cruise_deposit_treatment_missing])
        options[:focus] = "agreement"
      end
      departure_arrangement_cruise_agreement_path(@departure, @supplier_arrangement, **options)
    when :activation
      departure_arrangement_cruise_activation_path(@departure, @supplier_arrangement)
    when :advanced_planning
      departure_arrangement_path(@departure, @supplier_arrangement)
    end
  end

  def cruise_setup_shape_for(version)
    @cruise_setup_shapes ||= {}
    @cruise_setup_shapes[version&.id] ||= begin
      existing = @shape || @cruise_shape
      if existing&.version&.id == version&.id
        existing
      elsif version.nil? && existing
        existing
      else
        DetectCruiseArrangementShape.new(
          agency: Current.agency,
          arrangement: @supplier_arrangement,
          version: version
        ).call
      end
    end
  end

  def cruise_setup_summary_for(version)
    shape = cruise_setup_shape_for(version)
    return @summary if @summary && @shape&.version&.id == shape.version&.id

    nil
  end

  def cruise_setup_area_available?(area)
    return Current.agency_user.permitted?(:manage_departures) if area.key == :cabins || area.key == :rates

    true
  end

  def cruise_activation_blocker_path(blocker)
    case blocker.destination
    when :cabin_categories
      return unless Current.agency_user.permitted?(:manage_departures)

      cruise_cabin_corrective_path(blocker.resource_id, @supplier_arrangement_version)
    when :supplier_rates
      return unless Current.agency_user.permitted?(:manage_departures)

      cruise_supplier_rate_corrective_path(blocker.resource_id)
    when :agreement
      departure_arrangement_cruise_agreement_path(@departure, @supplier_arrangement, focus: "agreement")
    else
      departure_arrangement_activation_path(@departure, @supplier_arrangement)
    end
  end

  def cruise_activation_blocker_label(blocker)
    case blocker.destination
    when :cabin_categories then "Open Cabin inventory"
    when :supplier_rates then "Open Supplier rates"
    when :agreement then "Open Agreement"
    else "Open Advanced Supplier planning"
    end
  end

  def cruise_activation_recorded_on(activation)
    activation.activated_at.in_time_zone(activation.agency.default_timezone).strftime("%B %-d, %Y")
  end

  def cruise_activation_identifier(activation)
    activation.supplier_confirmation.supplier_issued_identifiers.filter_map(&:display_value).find(&:present?)
  end

  def cruise_cabin_corrective_path(resource_id, version)
    if Current.agency_user.permitted?(:manage_departures)
      if resource_id.present? && version&.draft?
        edit_departure_arrangement_cruise_cabin_category_path(@departure, @supplier_arrangement, resource_id)
      else
        departure_arrangement_cruise_cabin_categories_path(@departure, @supplier_arrangement)
      end
    else
      departure_arrangement_cruise_path(@departure, @supplier_arrangement, anchor: "cruise-cabins")
    end
  end

  def cruise_supplier_rates_workspace(summary = nil)
    @cruise_supplier_rates_workspace ||= CompileCruiseSupplierRatesWorkspace.new(
      agency: Current.agency,
      arrangement: @supplier_arrangement,
      shape: cruise_setup_detected_shape,
      readiness: summary&.activation_readiness,
      cabin_rows: summary&.cabin_rows
    ).call
  end

  def cruise_supplier_rates_summary(workspace)
    return "No cabin categories yet." if workspace.category_count.zero?

    parts = [ "#{workspace.category_count} #{'cabin category'.pluralize(workspace.category_count)}" ]
    parts << "#{workspace.contracted_count} contracted" if workspace.contracted_count.positive?
    parts << "#{workspace.estimate_count} #{'estimate'.pluralize(workspace.estimate_count)}" if workspace.estimate_count.positive?
    parts << "#{workspace.unrecorded_count} not recorded" if workspace.unrecorded_count.positive?
    parts << "#{workspace.advanced_count} advanced" if workspace.advanced_count.positive?
    parts.join(" · ")
  end

  def cruise_supplier_rate_editor_path(resource_id, stage: nil)
    options = {}
    options[:stage] = stage if stage.present?
    departure_arrangement_cruise_cabin_category_supplier_rates_path(
      @departure, @supplier_arrangement, resource_id, options
    )
  end

  def cruise_supplier_rate_corrective_path(resource_id)
    return departure_arrangement_cruise_supplier_rates_path(@departure, @supplier_arrangement) if resource_id.blank?

    row = cruise_supplier_rates_workspace.rows.find { |candidate| candidate.resource_id == resource_id }
    if row&.advanced?
      item = cruise_setup_detected_shape.item
      return departure_arrangement_path(@departure, @supplier_arrangement) unless item

      departure_arrangement_item_costs_workspace_path(@departure, @supplier_arrangement, item)
    elsif row
      cruise_supplier_rate_editor_path(resource_id, stage: row.stage)
    else
      departure_arrangement_cruise_supplier_rates_path(@departure, @supplier_arrangement)
    end
  end

  def cruise_supplier_rate_illustration_amount(illustration)
    return "Unavailable" unless illustration.available?

    Money.new(illustration.gross_minor_units, illustration.currency).format
  end

  def cruise_supplier_rate_scenario_amount(row, illustration)
    return "—" if row.advanced? || row.status_label == "Not recorded"

    cruise_supplier_rate_illustration_amount(illustration)
  end

  def cruise_cabin_inventory_workspace(summary = nil)
    CompileCruiseCabinInventoryWorkspace.new(
      agency: Current.agency,
      arrangement: @supplier_arrangement,
      shape: @shape || @cruise_shape,
      rows: summary&.cabin_rows,
      readiness: summary&.activation_readiness
    ).call
  end

  def cruise_cabin_inventory_summary(workspace)
    return "No cabin categories yet." if workspace.category_count.zero?

    parts = [ "#{workspace.category_count} #{'category'.pluralize(workspace.category_count)}" ]
    if workspace.tracked_cabin_count
      cabins = "#{workspace.tracked_cabin_count} #{'cabin'.pluralize(workspace.tracked_cabin_count)}"
      cabins = "#{workspace.tracked_cabin_count} tracked #{'cabin'.pluralize(workspace.tracked_cabin_count)}" if workspace.untracked_category_count.positive?
      parts << cabins
    end
    if workspace.untracked_category_count.positive?
      count = workspace.untracked_category_count
      parts << "#{count} #{'quantity'.pluralize(count)} not tracked"
    end
    posture = []
    posture << "#{workspace.carried_count} carried from active terms" if workspace.carried_count.positive?
    posture << "#{workspace.proposed_count} proposed" if workspace.proposed_count.positive?
    parts << posture.join(" · ") if posture.any?
    parts.join(" · ")
  end

  def cruise_cabin_inventory_quantity(row, workspace)
    if workspace.successor && !row.carried && row.quantity.present?
      "Proposed · #{row.quantity_label}"
    else
      row.quantity_label
    end
  end

  def cruise_cabin_evidence_status(row, workspace)
    if workspace.attention_items.any? { |item| item.resource_id == row.resource_id }
      "Needs attention"
    else
      "Complete"
    end
  end

  def cruise_setup_detected_shape
    @shape || @cruise_shape || DetectCruiseArrangementShape.new(
      agency: Current.agency,
      arrangement: @supplier_arrangement
    ).call
  end
end
