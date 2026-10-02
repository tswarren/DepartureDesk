# frozen_string_literal: true

class HotelAgreementWorkspace
  TERM_LABELS = {
    "deposit_derivation" => "Deposit derivation",
    "attrition" => "Attrition",
    "deposit_refund" => "Deposit refund",
    "destination_fee" => "Destination Fee",
    "additional_nights" => "Additional nights",
    "early_departure" => "Early departure",
    "cancellation" => "Cancellation"
  }.freeze

  TERM_HINTS = {
    "attrition" => "Minimum room usage and Supplier consequences if contracted pickup is not achieved.",
    "additional_nights" => "Supplier availability or pricing provisions outside the contracted stay.",
    "destination_fee" => "Supplier fee or waiver wording. This does not create a Supplier cost.",
    "early_departure" => "Supplier early-departure wording. No fee is calculated here.",
    "cancellation" => "Supplier cancellation wording. No charge is calculated here.",
    "deposit_derivation" => "How the Supplier derived the fixed deposits. This does not calculate them.",
    "deposit_refund" => "Governing refund wording. A date in this wording is not a Deadline."
  }.freeze

  TERM_GUIDANCE = {
    "attrition" => "Record the Supplier’s governing attrition wording. DepartureDesk does not calculate pickup or attrition from this text.",
    "destination_fee" => "Record the Supplier’s fee or waiver provision. This does not create a Supplier cost, negative cost, or Client discount.",
    "additional_nights" => "Record the Supplier’s availability or pricing wording. Additional inventory is created only when separately confirmed through the operational workflow.",
    "early_departure" => "Record the Supplier’s governing early-departure provision. No fee is calculated here.",
    "cancellation" => "Record the Supplier’s governing cancellation wording. DepartureDesk does not calculate cancellation charges from this text.",
    "deposit_derivation" => "Record how the Supplier derived the fixed deposits. This wording does not calculate them.",
    "deposit_refund" => "Record the original wording and the governing wording. A date in this text is not a Deadline."
  }.freeze

  DEADLINE_LABELS = {
    "deposit_due" => "Deposit due",
    "option_or_release_date" => "Option or release",
    "rooming_list_due" => "Rooming list due",
    "legal_names_due" => "Legal names due",
    "final_count_due" => "Final count due",
    "final_schedule_or_departure_time_due" => "Final schedule due",
    "cancellation_cutoff" => "Cancellation cutoff",
    "accessibility_confirmation_due" => "Accessibility confirmation due",
    "other" => "Other"
  }.freeze

  VersionFacts = Data.define(:record, :number, :role, :confirmation, :activation, :confirmed, :draft, :governing)
  StaySection = Data.define(:state, :definition, :arrival_on, :departure_on, :check_in, :check_out, :time_zone)
  InventorySection = Data.define(:state, :categories, :room_night_count)
  InventoryCategory = Data.define(:name, :nights)
  InventoryNight = Data.define(:date, :quantity, :attention)
  RateSection = Data.define(:state, :rows, :commission, :currency)
  RateRow = Data.define(:category, :date, :single, :double, :triple, :quad)
  MoneyRow = Data.define(
    :definition, :label, :due_on, :due_label, :amount_label, :shared, :thin, :advanced, :unassigned
  )
  TermRow = Data.define(:kind, :label, :hint, :state, :reference, :wide_reference, :agreement_wide)
  ConfirmationSection = Data.define(:confirmed, :evidence_on, :channel, :reference_note)
  SourceDefault = Data.define(:source_description, :supplier_reference, :external_reference, :evidence_note)
  Result = Data.define(
    :supplier_name, :arrangement_name, :item_name, :departure_name,
    :version, :version_options, :stay, :inventory, :rates,
    :deposits, :unassigned_deposits, :deadlines, :unassigned_deadlines,
    :terms, :confirmation, :source_default, :findings, :successor_available
  )

  def initialize(agency:, departure:, arrangement:, version:, item:)
    @agency = agency
    @departure = departure
    @arrangement = arrangement
    @version = version
    @item = item
  end

  def call
    inventory_shape = DetectHotelInventoryShape.new(
      agency: @agency, arrangement: @arrangement, version: @version, item: @item
    ).call
    rate_shape = DetectHotelRateShape.new(
      agency: @agency, arrangement: @arrangement, version: @version, item: @item, departure: @departure
    ).call
    illustration = IllustrateHotelSupplierRates.new(
      agency: @agency, departure: @departure, arrangement: @arrangement, version: @version, shape: rate_shape
    ).call
    stay = stay_section(inventory_shape)
    inventory = inventory_section(inventory_shape)
    rates = rate_section(rate_shape, illustration)
    deposit_rows = deposit_rows_for
    deadline_rows = deadline_rows_for
    terms = term_rows
    Result.new(
      supplier_name: @arrangement.contracting_supplier&.display_name,
      arrangement_name: @arrangement.name,
      item_name: item_definition&.name || @item.id,
      departure_name: @departure.name,
      version: version_facts(@version),
      version_options: version_options,
      stay: stay,
      inventory: inventory,
      rates: rates,
      deposits: deposit_rows.reject(&:unassigned),
      unassigned_deposits: deposit_rows.select(&:unassigned),
      deadlines: deadline_rows.reject(&:unassigned),
      unassigned_deadlines: deadline_rows.select(&:unassigned),
      terms: terms,
      confirmation: confirmation_section,
      source_default: source_default,
      findings: findings(stay, inventory, rates, deposit_rows, deadline_rows, terms),
      successor_available: successor_available?
    )
  end

  private

  def item_definition
    @item_definition ||= @version.arrangement_item_definitions.find_by(arrangement_item_id: @item.id)
  end

  def occurrences
    @occurrences ||= @version.service_occurrence_definitions
      .where(arrangement_item_id: @item.id)
      .order(:starts_on, :id)
      .to_a
  end

  def stay_section(shape)
    stays = occurrences.select { |occurrence| occurrence.starts_on != occurrence.ends_on }
    definition = stays.one? ? stays.first : nil
    state = if stays.many?
      "Needs attention"
    elsif definition.nil?
      "Not started"
    else
      "Recorded"
    end
    StaySection.new(
      state: state,
      definition: definition || shape.stay_definition,
      arrival_on: definition&.starts_on,
      departure_on: definition&.ends_on,
      check_in: definition&.starts_at_local,
      check_out: definition&.ends_at_local,
      time_zone: definition&.time_zone
    )
  end

  def inventory_section(shape)
    categories = shape.categories.map do |category|
      InventoryCategory.new(
        name: category.resource_definition.name,
        nights: category.cells.map do |cell|
          InventoryNight.new(
            date: cell.date,
            quantity: cell.supported? ? cell.pool_definition&.proposed_opening_quantity : nil,
            attention: cell.reason.present?
          )
        end
      )
    end
    state = if shape.resources.empty?
      "Not started"
    elsif ambiguous_inventory?(shape)
      "Needs attention"
    elsif shape.supported? && shape.cells.any? { |cell| cell.supported? && cell.pool_definition }
      "Recorded"
    else
      "In progress"
    end
    InventorySection.new(state: state, categories: categories, room_night_count: shape.room_night_count)
  end

  def ambiguous_inventory?(shape)
    shape.reasons.any? { |reason| reason.match?(/extra|Pool/i) } ||
      shape.cells.any? { |cell| cell.reason.to_s.match?(/Pool|extra/i) }
  end

  def rate_section(shape, illustration)
    rows = illustration.rows.map do |row|
      amounts = row.amounts || []
      RateRow.new(
        category: row.resource_definition.name,
        date: row.date,
        single: amounts[0],
        double: amounts[1],
        triple: amounts[2],
        quad: amounts[3]
      )
    end
    treatments = shape.contexts.filter_map { |context| context.definition&.commission_treatment }.uniq
    commission = case treatments
    when [ "noncommissionable" ] then "Noncommissionable"
    when [ "unspecified" ] then "Unspecified"
    when [] then nil
    else treatments.map(&:humanize).join(", ")
    end
    state = if shape.contexts.none? { |context| context.definition }
      "Not started"
    elsif shape.blocked? || shape.contexts.any? { |context| context.advanced || context.reason.to_s.match?(/More than one/) }
      "Needs attention"
    elsif shape.contexts.any? { |context| context.definition.nil? || context.reason.present? }
      "In progress"
    else
      "Recorded"
    end
    RateSection.new(state: state, rows: rows, commission: commission, currency: @departure.operating_currency)
  end

  def deposit_rows_for
    definitions = @version.supplier_deposit_requirement_definitions
      .includes(
        :supplier_deposit_requirement_definition_coverage_links,
        :supplier_deposit_requirement_definition_contributor_links,
        supplier_deposit_requirement_definition_cost_links: :supplier_cost_source
      )
      .order(:position, :id)
    definitions.filter_map { |definition| money_row_for_deposit(definition) }
  end

  def money_row_for_deposit(definition)
    coverage = definition.supplier_deposit_requirement_definition_coverage_links.sort_by(&:position)
    costs = definition.supplier_deposit_requirement_definition_cost_links
    relevance = deposit_relevance(coverage, costs)
    return if relevance == :other

    thin = thin_deposit?(definition, coverage, costs)
    MoneyRow.new(
      definition: definition,
      label: "Deposit",
      due_on: due_date(definition),
      due_label: due_label(definition),
      amount_label: deposit_amount_label(definition, thin),
      shared: shared_coverage?(coverage),
      thin: thin,
      advanced: relevance != :unassigned && !thin,
      unassigned: relevance == :unassigned
    )
  end

  def deposit_relevance(coverage, costs)
    item_ids = coverage.filter_map(&:arrangement_item_id).uniq
    return :included if item_ids.include?(@item.id)
    return :unassigned if coverage.empty? && costs.empty?
    return :cost if coverage.empty? && costs.all? { |link| link.supplier_cost_source&.arrangement_item_id == @item.id }

    :other
  end

  def thin_deposit?(definition, coverage, costs)
    definition.fixed_amount? && definition.fixed_date? && definition.date_only? &&
      costs.empty? && definition.supplier_deposit_requirement_definition_contributor_links.empty? &&
      item_only_coverage?(coverage)
  end

  def deadline_rows_for
    definitions = @version.supplier_deadline_definitions
      .includes(:supplier_deadline_definition_coverage_links, :supplier_deadline_commitment_definition_lines)
      .order(:position, :id)
    definitions.filter_map { |definition| money_row_for_deadline(definition) }
  end

  def money_row_for_deadline(definition)
    coverage = definition.supplier_deadline_definition_coverage_links.sort_by(&:position)
    item_ids = coverage.filter_map(&:arrangement_item_id).uniq
    unassigned = coverage.empty?
    return if !unassigned && item_ids.exclude?(@item.id)

    thin = thin_deadline?(definition, coverage)
    MoneyRow.new(
      definition: definition,
      label: DEADLINE_LABELS.fetch(definition.deadline_type, definition.display_label),
      due_on: due_date(definition),
      due_label: due_label(definition),
      amount_label: nil,
      shared: shared_coverage?(coverage),
      thin: thin,
      advanced: !unassigned && !thin,
      unassigned: unassigned
    )
  end

  def thin_deadline?(definition, coverage)
    simple_due = (definition.fixed_date? && definition.date_only?) ||
      (definition.fixed_local_datetime? && definition.local_date_time?)
    simple_due && definition.one_shared? &&
      definition.supplier_deadline_commitment_definition_lines.empty? &&
      item_only_coverage?(coverage)
  end

  def item_only_coverage?(coverage)
    coverage.one? && coverage.first.arrangement_item_id == @item.id &&
      coverage.first.service_occurrence_id.nil? &&
      coverage.first.supplier_resource_id.nil? &&
      coverage.first.capacity_pool_id.nil?
  end

  def shared_coverage?(coverage)
    coverage.filter_map(&:arrangement_item_id).uniq.many?
  end

  def deposit_amount_label(definition, thin)
    return nil unless thin || definition.fixed_amount?

    Money.new(definition.fixed_amount_minor_units, definition.currency).format if definition.fixed_amount_minor_units
  end

  def due_date(definition)
    parameters = definition.rule_parameters || {}
    if definition.fixed_date?
      Date.iso8601(parameters["date"])
    elsif definition.fixed_local_datetime?
      Date.iso8601(parameters["datetime"].to_s[0, 10])
    end
  rescue ArgumentError, TypeError
    nil
  end

  def due_label(definition)
    parameters = definition.rule_parameters || {}
    if definition.fixed_date? && parameters["date"].present?
      Date.iso8601(parameters["date"]).strftime("%B %-d, %Y")
    elsif definition.fixed_local_datetime? && parameters["datetime"].present?
      local_due_label(parameters["datetime"], definition.time_zone)
    else
      "Advanced configuration"
    end
  rescue ArgumentError, TypeError
    "Advanced configuration"
  end

  def local_due_label(value, time_zone)
    date_text, time_text = value.to_s.split("T", 2)
    date = Date.iso8601(date_text)
    hour, minute = time_text.to_s.split(":").map(&:to_i)
    stamp = Time.utc(date.year, date.month, date.day, hour, minute)
    "#{date.strftime("%B %-d, %Y")} at #{stamp.strftime("%-l:%M %P")} #{time_zone}"
  end

  def references
    @references ||= @version.supplier_agreement_references.order(:kind, :id).to_a
  end

  def term_rows
    SupplierAgreementReference::KINDS.map do |kind|
      scoped = references.select do |reference|
        reference.kind == kind &&
          (reference.arrangement_item_id.nil? || reference.arrangement_item_id == @item.id)
      end
      if SupplierAgreementReference::ITEM_KINDS.include?(kind)
        scoped = scoped.select { |reference| reference.arrangement_item_id == @item.id }
      end
      item_row = scoped.find { |reference| reference.arrangement_item_id == @item.id }
      wide_row = scoped.find { |reference| reference.arrangement_item_id.nil? }
      state = if item_row && wide_row
        "Needs attention"
      elsif item_row || wide_row
        "Recorded"
      else
        "Not recorded"
      end
      TermRow.new(
        kind: kind,
        label: TERM_LABELS.fetch(kind),
        hint: TERM_HINTS[kind],
        state: state,
        reference: item_row || wide_row,
        wide_reference: wide_row,
        agreement_wide: item_row.nil? && wide_row.present?
      )
    end
  end

  def confirmation_section
    confirmation = SupplierConfirmation.where(supplier_arrangement_version_id: @version.id).order(:recorded_at).last
    return ConfirmationSection.new(confirmed: false, evidence_on: nil, channel: nil, reference_note: nil) if confirmation.nil?

    ConfirmationSection.new(
      confirmed: true,
      evidence_on: confirmation.evidence_on,
      channel: confirmation.channel,
      reference_note: confirmation.reference_note
    )
  end

  def source_default
    relevant = references.select { |reference| reference.arrangement_item_id.nil? || reference.arrangement_item_id == @item.id }
    return if relevant.empty?

    keys = relevant.map { |reference| provenance_key(reference) }.uniq
    return unless keys.one?

    sample = relevant.first
    SourceDefault.new(
      source_description: sample.source_description,
      supplier_reference: sample.supplier_reference,
      external_reference: sample.external_reference,
      evidence_note: sample.evidence_note
    )
  end

  def provenance_key(reference)
    [
      reference.source_description, reference.supplier_reference,
      reference.external_reference, reference.evidence_note
    ]
  end

  def version_facts(version)
    confirmed = SupplierConfirmation.exists?(supplier_arrangement_version_id: version.id)
    governing = version.id == @arrangement.governing_version_id && version.activated?
    role = if version.superseded?
      "Superseded agreement"
    elsif governing
      "Current governing agreement"
    elsif version.draft? && version.copied_from_id.present?
      "Proposed successor draft"
    elsif version.abandoned?
      "Abandoned"
    else
      "Draft"
    end
    VersionFacts.new(
      record: version,
      number: version.version_number,
      role: role,
      confirmation: confirmed ? "Supplier confirmed" : "Not Supplier confirmed",
      activation: version.activated? ? "Activated" : "Not yet activated",
      confirmed: confirmed,
      draft: version.draft?,
      governing: governing
    )
  end

  def version_options
    @arrangement.versions.order(:version_number).map do |version|
      facts = version_facts(version)
      [ "v#{facts.number} · #{facts.role}", version.id ]
    end
  end

  def findings(stay, inventory, rates, deposits, deadlines, terms)
    notes = []
    notes << "More than one Stay is recorded for this Hotel." if stay.state == "Needs attention"
    notes << "The room block has conflicting inventory." if inventory.state == "Needs attention"
    notes << "Supplier rates need attention." if rates.state == "Needs attention"
    notes << "Deposit requirements on this version are not assigned to this stay." if deposits.any?(&:unassigned)
    notes << "Deadlines on this version are not assigned to this stay." if deadlines.any?(&:unassigned)
    if terms.any? { |term| term.state == "Needs attention" }
      notes << "An agreement term is recorded both for this stay and for the whole Supplier agreement."
    end
    missing_copies.each do |reference|
      notes << "Copied #{TERM_LABELS.fetch(reference.kind, reference.kind)} is missing from this successor."
    end
    notes
  end

  def missing_copies
    return [] if @version.copied_from_id.blank?

    predecessor_ids = SupplierAgreementReference.where(supplier_arrangement_version_id: @version.copied_from_id).pluck(:id)
    copied_ids = SupplierAgreementReference.where(
      supplier_arrangement_version_id: @version.id, copied_from_id: predecessor_ids
    ).pluck(:copied_from_id)
    SupplierAgreementReference.where(id: predecessor_ids - copied_ids).order(:kind, :id).to_a
  end

  def successor_available?
    @departure.active? && @arrangement.active? && @version.activated? &&
      @version.id == @arrangement.governing_version_id &&
      !@arrangement.versions.exists?(status: "draft")
  end
end
