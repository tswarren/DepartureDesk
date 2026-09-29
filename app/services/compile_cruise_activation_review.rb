# frozen_string_literal: true

# Read-only Cruise presentation of authoritative activation readiness.
# cruise_post_allowed? is not a second readiness predicate. It says only
# whether this review can safely post the existing activation command.
class CompileCruiseActivationReview
  KNOWN_BLOCKER_CODES = %i[
    opening_authority_incomplete
    cruise_contracted_rates_missing
    cruise_agreement_unconfirmed
    cruise_deposit_treatment_missing
  ].freeze

  STAFF_QUANTITY_SHAPES = %w[
    confirmed_quantity
    contracted_unit_rate_times_confirmed_quantity
  ].freeze
  STAFF_AMOUNT_SHAPES = %w[confirmed_amount].freeze
  RECOGNIZED_REQUIREMENTS = %w[initial_deposit hard_stop final_payment].freeze

  BlockerRow = Data.define(:code, :message, :destination, :known?, :resource_id)
  CabinRow = Data.define(:resource_id, :code, :name, :inventory_label, :quantity_label, :status_label)
  CostRow = Data.define(:source_id, :label, :stage_label, :represented?)
  TriggerRow = Data.define(
    :id, :description, :kind, :authority_shape, :represented?,
    :needs_quantity?, :needs_amount?
  )
  RequirementRow = Data.define(:key, :label, :detail, :recorded?)
  ElapsedRow = Data.define(:definition_id, :label, :due_label)
  Result = Data.define(
    :cruise_post_allowed?,
    :readiness_ready?,
    :activated?,
    :cost_sources_completely_represented?,
    :triggers_completely_represented?,
    :blockers,
    :cabins,
    :cost_rows,
    :triggers,
    :requirements,
    :consequences,
    :elapsed,
    :sailing,
    :agreement,
    :unsupported_reasons
  )

  def initialize(agency:, arrangement:, version: nil)
    @agency = agency
    @arrangement = arrangement
    @requested_version = version
  end

  def call
    shape = DetectCruiseArrangementShape.new(
      agency: @agency,
      arrangement: @arrangement,
      version: @requested_version
    ).call
    version = shape.version
    return incompatible_result(shape) if version.nil?

    readiness = SupplierArrangementActivationReadiness.new(
      agency: @agency,
      arrangement: @arrangement,
      version: version
    ).call
    activated = !version.draft?
    unsupported = []
    unsupported.concat(shape.reasons) unless shape.compatible?

    cost_rows = cost_rows_for(readiness)
    unless cost_rows.all?(&:represented?)
      unsupported << "A selected Supplier cost source cannot be represented on this Cruise review."
    end

    triggers = trigger_rows_for(version)
    unless triggers.all?(&:represented?)
      unsupported << "A confirmation trigger cannot be represented on this Cruise review."
    end

    consequences = consequences_for(version, unsupported)
    blockers = blocker_rows_for(readiness, version)
    estimate_selected = readiness.cost_selections.any? { |_source, definition| definition.estimate? }

    Result.new(
      cruise_post_allowed?: version.draft? &&
        shape.compatible? &&
        readiness.blockers.empty? &&
        !estimate_selected &&
        unsupported.empty?,
      readiness_ready?: readiness.ready?,
      activated?: activated,
      cost_sources_completely_represented?: cost_rows.all?(&:represented?),
      triggers_completely_represented?: triggers.all?(&:represented?),
      blockers: blockers,
      cabins: cabin_rows_for(version, shape),
      cost_rows: cost_rows,
      triggers: triggers,
      requirements: requirement_rows_for(version),
      consequences: consequences,
      elapsed: elapsed_rows_for(version),
      sailing: sailing_facts(shape, version),
      agreement: agreement_facts(version),
      unsupported_reasons: unsupported.uniq
    )
  end

  private

  def incompatible_result(shape)
    Result.new(
      cruise_post_allowed?: false,
      readiness_ready?: false,
      activated?: false,
      cost_sources_completely_represented?: false,
      triggers_completely_represented?: false,
      blockers: [],
      cabins: [],
      cost_rows: [],
      triggers: [],
      requirements: [],
      consequences: [],
      elapsed: [],
      sailing: {},
      agreement: {},
      unsupported_reasons: shape.reasons.presence || [ "This arrangement is not a Cruise review." ]
    )
  end

  def blocker_rows_for(readiness, version)
    readiness.blockers.map do |blocker|
      known = KNOWN_BLOCKER_CODES.include?(blocker.code)
      if known
        known_blocker(blocker, version)
      else
        BlockerRow.new(
          code: blocker.code,
          message: blocker.message,
          destination: :advanced,
          known?: false,
          resource_id: nil
        )
      end
    end
  end

  def known_blocker(blocker, version)
    case blocker.code
    when :opening_authority_incomplete
      definition = pool_definition_from(version, blocker.path)
      resource_definition = resource_definition_for(version, definition&.supplier_resource_id)
      pool = definition&.capacity_pool
      label = cabin_label(resource_definition)
      message = if definition&.proposed_opening_quantity.to_i.positive?
        "#{label} is #{inventory_label(pool)} inventory but its opening evidence is incomplete."
      else
        "#{label} is #{inventory_label(pool)} inventory but does not have an opening cabin quantity."
      end
      BlockerRow.new(
        code: blocker.code,
        message: message,
        destination: :cabin_categories,
        known?: true,
        resource_id: resource_definition&.supplier_resource_id
      )
    when :cruise_contracted_rates_missing
      definition = resource_definition_from(version, blocker.path)
      BlockerRow.new(
        code: blocker.code,
        message: "#{cabin_label(definition)} needs ready contracted Supplier rates.",
        destination: :supplier_rates,
        known?: true,
        resource_id: definition&.supplier_resource_id
      )
    when :cruise_agreement_unconfirmed
      BlockerRow.new(
        code: blocker.code,
        message: "Confirm the Cruise supplier agreement before activation.",
        destination: :agreement,
        known?: true,
        resource_id: nil
      )
    when :cruise_deposit_treatment_missing
      BlockerRow.new(
        code: blocker.code,
        message: "Record the deposit treatment for this supplemental block before activation.",
        destination: :agreement,
        known?: true,
        resource_id: nil
      )
    end
  end

  def cabin_rows_for(version, shape)
    return [] unless shape.compatible?

    occurrence_id = shape.occurrence&.id
    version.supplier_resource_definitions.includes(:supplier_resource).order(:position, :id).map do |definition|
      resource = definition.supplier_resource
      pool_definition = version.capacity_pool_definitions.includes(:capacity_pool).find do |pool_definition|
        pool_definition.supplier_resource_id == resource.id &&
          pool_definition.service_occurrence_id == occurrence_id
      end
      pool = pool_definition&.capacity_pool
      quantity = if pool.nil? || !pool.numeric_inventory?
        "—"
      else
        pool_definition.proposed_opening_quantity&.to_s || "—"
      end
      status = if pool.nil?
        "Needs attention"
      elsif !pool.numeric_inventory?
        "Quantity not tracked"
      elsif pool_definition.proposed_opening_quantity.to_i.positive? && opening_evidence?(pool_definition)
        "Ready"
      else
        "Needs attention"
      end
      CabinRow.new(
        resource_id: resource.id,
        code: definition.supplier_code,
        name: definition.name,
        inventory_label: inventory_label(pool),
        quantity_label: quantity,
        status_label: status
      )
    end
  end

  def cost_rows_for(readiness)
    readiness.cost_selections.map do |source, definition|
      represented = definition.contracted? || definition.estimate?
      CostRow.new(
        source_id: source.id,
        label: source.label.presence || "Supplier cost source",
        stage_label: definition.contracted? ? "Contracted" : (definition.estimate? ? "Estimate" : definition.stage.to_s.humanize),
        represented?: represented
      )
    end
  end

  def trigger_rows_for(version)
    version.supplier_commitment_trigger_definitions.order(:position, :id).map do |trigger|
      represented = SupplierCommitmentTriggerDefinition::TRIGGER_KINDS.include?(trigger.trigger_kind) &&
        SupplierCommitmentTriggerDefinition::AUTHORITY_SHAPES.include?(trigger.authority_shape)
      TriggerRow.new(
        id: trigger.id,
        description: trigger.description.presence || trigger.authority_shape.to_s.humanize,
        kind: trigger.trigger_kind,
        authority_shape: trigger.authority_shape,
        represented?: represented,
        needs_quantity?: STAFF_QUANTITY_SHAPES.include?(trigger.authority_shape),
        needs_amount?: STAFF_AMOUNT_SHAPES.include?(trigger.authority_shape)
      )
    end
  end

  def requirement_rows_for(version)
    deposits = version.supplier_deposit_requirement_definitions.order(:position, :id).to_a
    deadlines = version.supplier_deadline_definitions.order(:position, :id).to_a
    preview = PreviewCruiseDepositsAndDeadlinesActivation.call(
      agency: @agency,
      arrangement: @arrangement,
      version: version,
      version_lock_version: version.lock_version
    )
    rows_by_id = preview.rows.index_by(&:definition_id)
    recorded = {}

    deposits.each do |definition|
      key = CruiseDepositTemplateSupport.recognize_template(definition)
      next unless key == "initial_deposit"

      row = rows_by_id[definition.id]
      detail = [ row&.amount_sentence, row&.due_sentence && "Due #{row.due_sentence}" ].compact.join(". ")
      recorded["initial_deposit"] = RequirementRow.new(
        key: "initial_deposit",
        label: "Initial Deposit",
        detail: detail.presence || definition.description.to_s,
        recorded?: true
      )
    end

    deadlines.each do |definition|
      key = CruiseDeadlineTemplateSupport.recognize_template(definition)
      next unless %w[hard_stop final_payment].include?(key)

      row = rows_by_id[definition.id]
      detail = [ row&.due_sentence, definition.description.presence ].compact.join(". ")
      recorded[key] = RequirementRow.new(
        key: key,
        label: key == "hard_stop" ? "Hard Stop" : "Final Payment",
        detail: detail.presence || "Recorded",
        recorded?: true
      )
    end

    RECOGNIZED_REQUIREMENTS.map do |key|
      recorded[key] || RequirementRow.new(
        key: key,
        label: { "initial_deposit" => "Initial Deposit", "hard_stop" => "Hard Stop", "final_payment" => "Final Payment" }.fetch(key),
        detail: "Not recorded",
        recorded?: false
      )
    end
  end

  def consequences_for(version, unsupported)
    sentences = []
    version.capacity_pool_definitions.includes(:capacity_pool, :supplier_resource).order(:position, :id).each do |definition|
      pool = definition.capacity_pool
      label = cabin_label(resource_definition_for(version, definition.supplier_resource_id))
      if pool.nil?
        unsupported << "A cabin pool cannot be explained on this Cruise review."
        next
      elsif !pool.numeric_inventory?
        sentences << "#{label} stays #{inventory_label(pool).downcase}. Quantity is not tracked."
      elsif pool.capacity_events.exists?
        sentences << "#{label} capacity will be carried."
      else
        quantity = definition.proposed_opening_quantity
        sentences << "#{label} opening quantity of #{quantity || "the recorded number"} will be established."
      end
    end

    version.supplier_deposit_requirement_definitions.order(:position, :id).each do |definition|
      evaluated = SupplierDepositAmountEvaluator.call(
        definition: definition,
        version: version,
        arrangement: @arrangement,
        mode: :preview
      )
      label = definition.description.presence || "Deposit requirement"
      sentences << if evaluated[:quantity_not_tracked]
        "#{label} will not open a deposit commitment because quantity is not tracked."
      else
        "#{label} will materialize from its current evaluation."
      end
    rescue SupplierDepositAmountEvaluator::IncompleteCalculation
      sentences << "#{definition.description.presence || "Deposit requirement"} cannot be evaluated yet."
    end

    version.supplier_deadline_definitions.order(:position, :id).each do |definition|
      sentences << "#{definition.display_label.presence || definition.description.presence || "Supplier deadline"} will materialize."
    end

    triggers = version.supplier_commitment_trigger_definitions.order(:position, :id)
    if triggers.none?
      sentences << "No confirmation-triggered commitments will open."
    else
      triggers.each do |trigger|
        label = trigger.description.presence || "Confirmation trigger"
        sentences << if trigger.arrangement_confirmation?
          "#{label} will open when this version is activated."
        else
          "#{label} will not open on this activation."
        end
      end
    end
    sentences
  end

  def elapsed_rows_for(version)
    departure = @arrangement.departure
    deadline_rows = MaterializeSupplierDeadlineDefinitionsAlreadyLocked.new(
      agency: @agency,
      actor: nil,
      arrangement: @arrangement,
      version: version,
      activation: nil,
      departure: departure
    ).preview_elapsed
    deposit_rows = MaterializeSupplierDepositRequirementDefinitionsAlreadyLocked.new(
      agency: @agency,
      actor: nil,
      arrangement: @arrangement,
      version: version,
      activation: nil,
      departure: departure
    ).preview_elapsed
    (deadline_rows + deposit_rows).map do |row|
      definition = row[:definition]
      due = row[:calculated_on]&.strftime("%B %-d, %Y") ||
        row[:calculated_at]&.in_time_zone(definition.time_zone)&.strftime("%B %-d, %Y")
      ElapsedRow.new(
        definition_id: definition.id,
        label: definition.try(:display_label).presence || definition.description.presence || "Supplier requirement",
        due_label: due
      )
    end
  end

  def sailing_facts(shape, version)
    summary = shape.summary || {}
    predecessor = version.copied_from
    {
      supplier_name: @arrangement.contracting_supplier&.display_name_for_directory,
      ship_name: summary["ship_name"],
      sailing_name: summary["sailing_name"],
      starts_on: format_iso_date(summary["starts_on"]),
      ends_on: format_iso_date(summary["ends_on"]),
      version_number: version.version_number,
      successor?: predecessor.present?,
      governing_version_number: @arrangement.governing_version&.version_number
    }
  end

  def agreement_facts(version)
    confirmation = version.supplier_arrangement_cruise_agreement_confirmations.find_by(current: true)
    {
      confirmed?: confirmation&.status == "confirmed",
      status_label: confirmation&.status&.humanize || "Not recorded",
      group_reference: confirmation&.group_reference,
      contract_date: confirmation&.contract_date&.strftime("%B %-d, %Y")
    }
  end

  def pool_definition_from(version, path)
    id = path.to_s[/pools\.([0-9a-f-]{36})\z/, 1]
    return nil if id.blank?

    version.capacity_pool_definitions.includes(:capacity_pool, :supplier_resource).find_by(id: id)
  end

  def resource_definition_from(version, path)
    id = path.to_s[/resources\.([0-9a-f-]{36})\z/, 1]
    return nil if id.blank?

    version.supplier_resource_definitions.includes(:supplier_resource).find_by(id: id)
  end

  def resource_definition_for(version, supplier_resource_id)
    return nil if supplier_resource_id.blank?

    version.supplier_resource_definitions.find_by(supplier_resource_id: supplier_resource_id)
  end

  def cabin_label(definition)
    return "Cabin category" if definition.nil?

    [ definition.supplier_code.presence, definition.name.presence ].compact.join(" ").presence || "Cabin category"
  end

  def inventory_label(pool)
    return "Inventory" if pool.nil?

    {
      "block" => "Block",
      "allotment" => "Allotment",
      "on_request" => "On request",
      "externally_managed" => "Externally managed"
    }.fetch(pool.inventory_mode, pool.inventory_mode.to_s.humanize)
  end

  def opening_evidence?(definition)
    definition.override? || (
      definition.evidence_kind.present? &&
      definition.evidence_on.present? &&
      definition.evidence_reference_note.present?
    )
  end

  def format_iso_date(value)
    return nil if value.blank?

    Date.iso8601(value).strftime("%B %-d, %Y")
  rescue ArgumentError
    value
  end
end
