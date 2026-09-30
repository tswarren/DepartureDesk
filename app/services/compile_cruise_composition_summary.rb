# frozen_string_literal: true

class CompileCruiseCompositionSummary
  Section = Data.define(:key, :title, :status_label, :detail)
  CabinRow = Data.define(
    :resource_id, :code, :name, :occupancy_label, :inventory_label, :quantity_label,
    :quantity, :opening_quantity_label, :carried, :rate_posture, :advanced_rates, :removable
  )
  MaintenanceStep = Data.define(:code, :message, :resource_id)
  RequirementRow = Data.define(:key, :label, :detail)
  TermRow = Data.define(:key, :label, :status_label, :recorded, :advanced)
  BlockerRow = Data.define(:code, :message, :path, :cruise_coded)
  RecommendedNextAction = Data.define(:key, :label, :detail, :resource_id, :blocker_code, :advanced)
  Activation = Data.define(:ready, :status_label, :detail, :blockers)
  Result = Data.define(
    :sections, :recommended_next_action, :cabin_rows, :requirement_rows, :term_rows, :activation,
    :maintenance_steps, :activation_readiness
  )
  MAINTENANCE_CODES = %i[
    opening_authority_incomplete
    cruise_agreement_unconfirmed
    cruise_contracted_rates_missing
    cruise_deposit_treatment_missing
  ].freeze

  CRUISE_BLOCKER_PRIORITY = %i[
    cruise_agreement_unconfirmed
    cruise_contracted_rates_missing
    cruise_deposit_treatment_missing
  ].freeze

  INVENTORY_LABELS = {
    "block" => "Fixed block",
    "allotment" => "Replenishable allotment",
    "on_request" => "On request",
    "externally_managed" => "Externally managed"
  }.freeze

  KNOWN_TERM_KEYS = %w[
    allocated_cabin_deposit
    card_restrictions
    cancellation_step
    tour_conductor_credit
    group_amenity_program
  ].freeze

  def initialize(agency:, arrangement:, shape:)
    @agency = agency
    @arrangement = arrangement
    @shape = shape
  end

  def call
    version = @shape.version
    @confirmation = version.supplier_arrangement_cruise_agreement_confirmations.find_by(current: true)
    @cabin_rows = cabin_rows(version)
    @deposits = version.supplier_deposit_requirement_definitions
      .includes(:supplier_deposit_requirement_definition_coverage_links)
      .order(:position, :id)
      .to_a
    @deadlines = version.supplier_deadline_definitions.order(:position, :id).to_a
    @requirement_rows = requirement_rows
    @term_rows = term_rows(version)
    readiness = SupplierArrangementActivationReadiness.new(
      agency: @agency, arrangement: @arrangement, version: version
    ).call
    @blockers = readiness.blockers.map { |blocker|
      BlockerRow.new(
        code: blocker.code,
        message: blocker.message,
        path: blocker.path,
        cruise_coded: CRUISE_BLOCKER_PRIORITY.include?(blocker.code)
      )
    }
    resource_definitions = version.supplier_resource_definitions.order(:position, :id).to_a
    @activation = activation_summary
    recommended = recommended_next_action(resource_definitions)

    Result.new(
      sections: sections,
      recommended_next_action: recommended,
      cabin_rows: @cabin_rows,
      requirement_rows: @requirement_rows,
      term_rows: @term_rows,
      activation: @activation,
      maintenance_steps: maintenance_steps(version),
      activation_readiness: readiness
    )
  end

  # Full cabin rows shared with Cabin inventory. Includes quantity, opening, carried, and rate posture.
  def cabin_inventory_rows
    version = @shape.version
    return [] if version.nil?

    cabin_rows(version)
  end

  # Rate posture for Cruise setup navigation. Skips card quantities and removal checks.
  def navigation_cabin_rows
    version = @shape.version
    return [] if version.nil?

    version.supplier_resource_definitions.includes(:supplier_resource).order(:position, :id).map do |definition|
      shape = DetectCruiseSupplierRateShape.new(
        agency: @agency,
        arrangement: @arrangement,
        resource: definition.supplier_resource,
        version: version
      ).call
      posture, advanced = rate_posture(shape)
      CabinRow.new(
        resource_id: definition.supplier_resource_id,
        code: definition.supplier_code.presence,
        name: definition.name,
        occupancy_label: nil,
        inventory_label: nil,
        quantity_label: nil,
        quantity: nil,
        opening_quantity_label: nil,
        carried: false,
        rate_posture: posture,
        advanced_rates: advanced,
        removable: false
      )
    end
  end

  def self.presentation_blocker(blockers, resource_definitions: [])
    agreement = blockers.find { |blocker| blocker.code == :cruise_agreement_unconfirmed }
    return agreement if agreement

    rate_blockers = blockers.select { |blocker| blocker.code == :cruise_contracted_rates_missing }
    if rate_blockers.any?
      ordered_paths = resource_definitions.sort_by { |definition| [ definition.position.to_i, definition.id.to_s ] }
        .map { |definition| "resources.#{definition.id}" }
      chosen = ordered_paths.filter_map { |path| rate_blockers.find { |blocker| blocker.path == path } }.first
      return chosen || rate_blockers.first
    end

    treatment = blockers.find { |blocker| blocker.code == :cruise_deposit_treatment_missing }
    return treatment if treatment

    blockers.first
  end

  private

  def cabin_rows(version)
    pool_definitions = version.capacity_pool_definitions.includes(:capacity_pool).index_by(&:supplier_resource_id)
    carried_ids = carried_pool_ids(version)
    version.supplier_resource_definitions.includes(:supplier_resource).order(:position, :id).map do |definition|
      pool_definition = pool_definitions[definition.supplier_resource_id]
      pool = pool_definition&.capacity_pool
      shape = DetectCruiseSupplierRateShape.new(
        agency: @agency,
        arrangement: @arrangement,
        resource: definition.supplier_resource,
        version: version
      ).call
      posture, advanced = rate_posture(shape)
      carried = carried_ids.include?(pool&.id)
      quantity = cabin_quantity(pool, pool_definition, version, carried: carried)
      CabinRow.new(
        resource_id: definition.supplier_resource_id,
        code: definition.supplier_code.presence,
        name: definition.name,
        occupancy_label: occupancy_label(definition.maximum_occupancy),
        inventory_label: inventory_label(pool, pool_definition),
        quantity_label: quantity_label(pool, pool_definition, quantity, carried: carried, activated: version.activated?),
        quantity: quantity,
        opening_quantity_label: opening_quantity_label(pool, pool_definition, version),
        carried: carried,
        rate_posture: posture,
        advanced_rates: advanced,
        removable: RemoveCruiseCabinCategory.possible?(version: version, resource: definition.supplier_resource)
      )
    end
  end

  def rate_posture(shape)
    return [ :unsupported, true ] unless shape.compatible?
    return [ :missing, false ] if shape.empty? || shape.summary[:state] == "missing"

    definitions = shape.source&.supplier_cost_definitions.to_a
    if definitions.any? { |definition| definition.contracted? && definition.forecast_ready? }
      [ :contracted_ready, false ]
    elsif definitions.any?(&:contracted?)
      [ :contracted_working, false ]
    elsif definitions.any?(&:estimate?)
      [ :estimated, false ]
    else
      [ :working, false ]
    end
  end

  def cabin_quantity(pool, pool_definition, version, carried:)
    return nil unless CruiseCabinCategorySupport.typed_cabin_pool?(pool, pool_definition)
    return nil unless pool.numeric_inventory?
    return nil if carried

    if version.activated?
      pool.capacity_projection&.current_supplier_capacity
    else
      quantity = pool_definition.proposed_opening_quantity
      quantity if quantity.present?
    end
  end

  def carried_pool_ids(version)
    return [] unless version.draft? && version.copied_from_id.present?

    version.copied_from.capacity_pool_definitions.pluck(:capacity_pool_id)
  end

  def occupancy_label(maximum)
    return nil if maximum.blank?

    "sleeps up to #{maximum}"
  end

  def inventory_label(pool, pool_definition)
    return "Inventory not configured" unless CruiseCabinCategorySupport.typed_cabin_pool?(pool, pool_definition)

    INVENTORY_LABELS.fetch(pool.inventory_mode, pool.inventory_mode.to_s.tr("_", " "))
  end

  def quantity_label(pool, pool_definition, quantity, carried:, activated:)
    return "Quantity not tracked" unless CruiseCabinCategorySupport.typed_cabin_pool?(pool, pool_definition)
    return "Quantity not tracked" unless pool.numeric_inventory?
    return "Carried from active terms" if carried
    return "Cabin quantity not set" if quantity.blank?

    label = "#{quantity} #{"cabin".pluralize(quantity)}"
    activated ? "Current active capacity: #{label}" : label
  end

  def opening_quantity_label(pool, pool_definition, version)
    return nil unless version.activated?
    return nil unless CruiseCabinCategorySupport.typed_cabin_pool?(pool, pool_definition)
    return nil unless pool.numeric_inventory?

    quantity = pool_definition.proposed_opening_quantity
    return nil if quantity.blank?

    "Original opening quantity: #{quantity} #{"cabin".pluralize(quantity)}"
  end

  def maintenance_steps(version)
    return [] unless version.draft? && version.copied_from_id.present?

    MAINTENANCE_CODES.filter_map do |code|
      @blockers.select { |blocker| blocker.code == code }.map do |blocker|
        MaintenanceStep.new(
          code: code,
          message: blocker.message,
          resource_id: maintenance_resource_id(version, blocker)
        )
      end
    end.flatten
  end

  def maintenance_resource_id(version, blocker)
    case blocker.code
    when :cruise_contracted_rates_missing
      definition_id = blocker.path.to_s.delete_prefix("resources.")
      version.supplier_resource_definitions.find_by(id: definition_id)&.supplier_resource_id
    when :opening_authority_incomplete
      definition_id = blocker.path.to_s.split(".pools.").last
      version.capacity_pool_definitions.find_by(id: definition_id)&.supplier_resource_id
    end
  end

  def requirement_rows
    claimed_deposit_ids = []
    claimed_deadline_ids = []
    rows = []

    initial = @deposits.find { |definition| CruiseDepositTemplateSupport.recognize_template(definition) == "initial_deposit" }
    if initial
      claimed_deposit_ids << initial.id
      rows << RequirementRow.new(key: "initial_deposit", label: "Initial group deposit", detail: initial.description)
    end

    hard_stop = @deadlines.find { |definition| CruiseDeadlineTemplateSupport.recognize_template(definition) == "option_or_release" }
    if hard_stop
      claimed_deadline_ids << hard_stop.id
      rows << RequirementRow.new(key: "hard_stop", label: "Hard stop", detail: hard_stop.description)
    end

    final_payment = @deadlines.find { |definition| CruiseDeadlineTemplateSupport.recognize_template(definition) == "final_payment" }
    if final_payment
      claimed_deadline_ids << final_payment.id
      rows << RequirementRow.new(key: "final_payment", label: "Final payment", detail: final_payment.description)
    end

    @deposits.each do |definition|
      next if claimed_deposit_ids.include?(definition.id)

      template = CruiseDepositTemplateSupport.recognize_template(definition)
      rows << RequirementRow.new(
        key: template.presence || "additional_deposit",
        label: additional_deposit_label(template, definition),
        detail: definition.description
      )
    end
    @deadlines.each do |definition|
      next if claimed_deadline_ids.include?(definition.id)

      template = CruiseDeadlineTemplateSupport.recognize_template(definition)
      rows << RequirementRow.new(
        key: template.presence || "additional_deadline",
        label: additional_deadline_label(template, definition),
        detail: definition.description
      )
    end
    rows
  end

  def additional_deposit_label(template, definition)
    case template
    when "other_deposit" then "Other deposit"
    when "final_deposit" then "Cumulative deposit"
    else definition.description.presence || "Additional deposit requirement"
    end
  end

  def additional_deadline_label(template, definition)
    case template
    when "option_or_release" then "Option or release"
    when "rooming_list" then "Rooming list"
    when "other" then definition.other_label.presence || "Other Supplier deadline"
    else definition.description.presence || definition.other_label.presence || "Additional Supplier deadline"
    end
  end

  def term_rows(version)
    cruise_terms = version.supplier_arrangement_cruise_term_definitions.order(:term_type, :position).to_a
    benefits = version.supplier_arrangement_commercial_benefit_definitions.order(:term_type).to_a
    rows = []
    rows << term_presence(
      "allocated_cabin_deposit",
      "Allocated cabin deposit",
      cruise_terms.any?(&:allocated_cabin_deposit?)
    )
    rows << term_presence(
      "card_restrictions",
      "Card restrictions",
      cruise_terms.any?(&:card_restrictions?)
    )
    cancellation = cruise_terms.select(&:cancellation_step?)
    rows << TermRow.new(
      key: "cancellation_step",
      label: "Cancellation terms",
      status_label: cancellation.any? ? "#{cancellation.size} #{"step".pluralize(cancellation.size)} recorded" : "Not recorded",
      recorded: cancellation.any?,
      advanced: false
    )
    rows << term_presence(
      "tour_conductor_credit",
      "Tour-conductor credit",
      benefits.any?(&:tour_conductor_credit?)
    )
    rows << term_presence(
      "group_amenity_program",
      "Group Amenity Program",
      benefits.any?(&:group_amenity_program?)
    )

    cruise_terms.map(&:term_type).uniq.each do |term_type|
      next if KNOWN_TERM_KEYS.include?(term_type)

      rows << TermRow.new(
        key: term_type,
        label: "Additional Supplier term — Review in Advanced",
        status_label: "Review in Advanced",
        recorded: true,
        advanced: true
      )
    end
    benefits.map(&:term_type).uniq.each do |term_type|
      next if KNOWN_TERM_KEYS.include?(term_type)

      rows << TermRow.new(
        key: term_type,
        label: "Additional Supplier term — Review in Advanced",
        status_label: "Review in Advanced",
        recorded: true,
        advanced: true
      )
    end
    rows
  end

  def term_presence(key, label, recorded)
    TermRow.new(
      key: key,
      label: label,
      status_label: recorded ? "Recorded" : "Not recorded",
      recorded: recorded,
      advanced: false
    )
  end

  def activation_summary
    cruise_messages = @blockers.select(&:cruise_coded).map(&:message)
    other_count = @blockers.count { |blocker| !blocker.cruise_coded }
    if @blockers.empty?
      Activation.new(
        ready: true,
        status_label: "Ready to review",
        detail: "No blocking issues found.",
        blockers: @blockers
      )
    else
      detail = cruise_messages.dup
      if other_count.positive?
        verb = other_count == 1 ? "is" : "are"
        detail << "#{other_count} #{"other issue".pluralize(other_count)} #{verb} on the activation review."
      end
      Activation.new(
        ready: false,
        status_label: "Not ready",
        detail: detail.join(" "),
        blockers: @blockers
      )
    end
  end

  def sections
    [
      sailing_section,
      cabins_section,
      rates_section,
      agreement_section,
      requirements_section,
      terms_section,
      Section.new(
        key: "activation",
        title: "Activation",
        status_label: @activation.status_label,
        detail: @activation.detail
      )
    ]
  end

  def sailing_section
    occurrence = @shape.occurrence_definition
    detail = [
      @shape.summary["ship_name"],
      sailing_dates(occurrence),
      @shape.summary["sailing_name"]
    ].compact_blank.join(" · ")
    Section.new(key: "sailing", title: "Sailing", status_label: "Recorded", detail: detail)
  end

  def sailing_dates(occurrence)
    return nil if occurrence.nil?

    "#{staff_date(occurrence.starts_on)}–#{staff_date(occurrence.ends_on)}"
  end

  def cabins_section
    if @cabin_rows.empty?
      return Section.new(key: "cabins", title: "Cabin categories", status_label: "Not entered", detail: "No cabin categories yet.")
    end

    quantities = @cabin_rows.map(&:quantity)
    detail = if quantities.all?
      total = quantities.sum
      "#{@cabin_rows.size} · #{total} #{"cabin".pluralize(total)}"
    else
      "#{@cabin_rows.size} #{"cabin category".pluralize(@cabin_rows.size)}"
    end
    Section.new(key: "cabins", title: "Cabin categories", status_label: "Recorded", detail: detail)
  end

  def rates_section
    if @cabin_rows.empty?
      return Section.new(key: "rates", title: "Supplier rates", status_label: "Waiting for categories", detail: "Add cabin categories before Supplier rates.")
    end

    ready = @cabin_rows.count { |row| row.rate_posture == :contracted_ready }
    estimated = @cabin_rows.count { |row| %i[estimated contracted_working working].include?(row.rate_posture) }
    missing = @cabin_rows.count { |row| row.rate_posture == :missing }
    advanced = @cabin_rows.count(&:advanced_rates)
    if missing == @cabin_rows.size
      return Section.new(key: "rates", title: "Supplier rates", status_label: "Not entered", detail: "No Supplier rates yet.")
    end

    parts = []
    parts << "#{ready} contracted" if ready.positive?
    parts << "#{estimated} estimated" if estimated.positive?
    parts << "#{missing} not entered" if missing.positive?
    parts << "#{advanced} advanced" if advanced.positive?
    status = (missing.zero? && estimated.zero? && advanced.zero?) ? "Recorded" : "Needs attention"
    Section.new(key: "rates", title: "Supplier rates", status_label: status, detail: parts.join(" · "))
  end

  def agreement_section
    confirmation = @confirmation
    if confirmation.nil?
      return Section.new(key: "agreement", title: "Agreement", status_label: "Not recorded", detail: "The Supplier agreement has not been recorded.")
    end
    if confirmation.provisional?
      return Section.new(
        key: "agreement",
        title: "Agreement",
        status_label: "Provisional",
        detail: "Group created #{staff_date(confirmation.group_creation_date)}. Group number and contract date are not confirmed."
      )
    end

    Section.new(
      key: "agreement",
      title: "Agreement",
      status_label: "Confirmed #{staff_date(confirmation.contract_date)}",
      detail: "Group #{confirmation.group_reference}"
    )
  end

  def requirements_section
    recognized = @requirement_rows.select { |row| %w[initial_deposit hard_stop final_payment].include?(row.key) }
    additional = @requirement_rows.reject { |row| %w[initial_deposit hard_stop final_payment].include?(row.key) }
    if @requirement_rows.empty?
      return Section.new(key: "requirements", title: "Requirements", status_label: "Not recorded", detail: "No deposits or deadlines recorded.")
    end

    labels = recognized.map(&:label)
    labels << "#{additional.size} additional" if additional.any?
    status = recognized.size == 3 ? "Recorded" : "Needs attention"
    Section.new(key: "requirements", title: "Requirements", status_label: status, detail: labels.join(" · "))
  end

  def terms_section
    recorded = @term_rows.count(&:recorded)
    Section.new(
      key: "terms",
      title: "Supplier terms",
      status_label: recorded.positive? ? "#{recorded} recorded" : "None recorded",
      detail: "Optional terms stay quiet until the agreement includes them."
    )
  end

  def recommended_next_action(resource_definitions)
    missing_rates = @cabin_rows.find { |row| row.rate_posture == :missing }
    if @cabin_rows.empty?
      return action(:add_cabins, "Add cabin categories", "Add the cabin categories the Supplier is holding for this group.")
    end
    if missing_rates
      return action(
        :add_rates,
        "Enter Supplier rates",
        "Enter Supplier rates for #{cabin_name(missing_rates)}.",
        resource_id: missing_rates.resource_id,
        advanced: missing_rates.advanced_rates
      )
    end
    unless @confirmation&.confirmed?
      label = @confirmation&.provisional? ? "Finish the Supplier agreement" : "Record the Supplier agreement"
      return action(:record_agreement, label, "Group number and contract date can be confirmed when the contract is in hand.")
    end

    gaps = activation_requirement_gaps
    if gaps.any?
      return requirement_recommendation(gaps)
    end

    if @blockers.any?
      chosen = self.class.presentation_blocker(@blockers, resource_definitions: resource_definitions)
      others = @blockers.size - 1
      detail = if others.zero?
        "This is the only activation issue."
      elsif others == 1
        "1 other issue is listed under Activation."
      else
        "#{others} other issues are listed under Activation."
      end
      return action(:resolve_blocker, chosen.message, detail, blocker_code: chosen.code)
    end

    action(:review_activation, "Review activation", "Review this Supplier arrangement for activation.")
  end

  def activation_requirement_gaps
    gaps = []
    gaps << :contracted_rates if @cabin_rows.any? { |row| row.rate_posture != :contracted_ready }
    gaps << :initial_deposit unless @requirement_rows.any? { |row| row.key == "initial_deposit" }
    gaps << :hard_stop unless @requirement_rows.any? { |row| row.key == "hard_stop" }
    gaps << :final_payment unless @requirement_rows.any? { |row| row.key == "final_payment" }
    gaps
  end

  def requirement_recommendation(gaps)
    chosen = gaps.first
    detail = requirement_detail(gaps, chosen)
    case chosen
    when :contracted_rates
      cabin = @cabin_rows.find { |row| row.rate_posture != :contracted_ready }
      action(
        :review_contracted_rates,
        "Review contracted Supplier rates",
        detail,
        resource_id: cabin.resource_id,
        advanced: cabin.advanced_rates
      )
    when :initial_deposit
      action(:record_initial_deposit, "Record the initial group deposit", detail)
    when :hard_stop
      action(:record_hard_stop, "Record the hard stop", detail)
    else
      action(:record_final_payment, "Record final payment", detail)
    end
  end

  def requirement_detail(gaps, chosen)
    others = gaps - [ chosen ]
    sentences = []
    if chosen == :contracted_rates
      count = @cabin_rows.count { |row| row.rate_posture != :contracted_ready }
      sentences << "#{count} #{"cabin category".pluralize(count)} still #{count == 1 ? "needs" : "need"} ready contracted Supplier rates."
    end
    if others.include?(:contracted_rates)
      sentences << "Contracted Supplier rates still need attention."
    end
    if others.intersect?(%i[initial_deposit hard_stop final_payment])
      sentences << "Supplier requirements still need attention."
    end
    sentences.presence&.join(" ") || "This can be recorded when the agreement is in hand."
  end

  def action(key, label, detail, resource_id: nil, blocker_code: nil, advanced: false)
    RecommendedNextAction.new(
      key: key,
      label: label,
      detail: detail,
      resource_id: resource_id,
      blocker_code: blocker_code,
      advanced: advanced
    )
  end

  def cabin_name(row)
    [ row.code, row.name ].compact_blank.join(" ")
  end

  def staff_date(value)
    return nil if value.blank?

    date = value.is_a?(Date) ? value : Date.iso8601(value.to_s)
    date.strftime("%b %-d, %Y")
  end
end
