# frozen_string_literal: true

class CompileHotelActivationReview
  Blocker = Data.define(:code, :message, :target)
  Section = Data.define(:key, :label, :state, :detail)
  Result = Data.define(
    :workspace, :readiness, :sections, :blockers, :elapsed_labels,
    :confirmation_allowed, :revision_allowed, :activation_allowed, :confirmation
  )

  def initialize(agency:, departure:, arrangement:, version:, item:)
    @agency = agency
    @departure = departure
    @arrangement = arrangement
    @version = version
    @item = item
  end

  def call
    workspace = HotelAgreementWorkspace.new(
      agency: @agency, departure: @departure, arrangement: @arrangement,
      version: @version, item: @item
    ).call
    readiness = SupplierArrangementActivationReadiness.new(
      agency: @agency, arrangement: @arrangement, version: @version
    ).call
    confirmation = SupplierConfirmation.where(supplier_arrangement_version_id: @version.id).order(:recorded_at, :id).last
    hotel_blockers = hotel_blockers(workspace)
    other_lodging_blockers = other_lodging_blockers()
    blockers = hotel_blockers.dup
    blockers.concat(other_lodging_blockers) if confirmation.nil?
    blockers.concat(readiness_blockers(readiness)) if confirmation.present?
    hotel_clear = hotel_blockers.empty?
    confirmation_clear = hotel_clear && other_lodging_blockers.empty?
    elapsed_labels = elapsed_labels_for(workspace)
    provisional_selection = readiness.cost_selections.any? { |_source, definition| definition.estimate? }
    typed_attestations_safe = typed_activation_attestations_safe?
    if confirmation.present? && !typed_attestations_safe
      blockers << Blocker.new(
        code: :advanced_activation_shape,
        message: "This Supplier agreement needs Advanced Supplier planning before activation.",
        target: :activation
      )
    end
    if confirmation.present? && provisional_selection
      blockers << Blocker.new(
        code: :provisional_supplier_cost,
        message: "Operational Supplier setup still uses an estimated cost authority.",
        target: :activation
      )
    end
    draft = @version.draft? && @arrangement.editable_version&.id == @version.id
    Result.new(
      workspace: workspace,
      readiness: readiness,
      sections: sections_for(workspace, confirmation),
      blockers: blockers,
      elapsed_labels: elapsed_labels,
      confirmation_allowed: draft && confirmation.nil? && confirmation_clear,
      revision_allowed: revision_allowed?(confirmation),
      activation_allowed: draft && confirmation.present? && hotel_clear && readiness.ready? &&
        !provisional_selection && typed_attestations_safe,
      confirmation: confirmation
    )
  end

  private

  def sections_for(workspace, confirmation)
    rooming = workspace.deadlines.find { |row| row.definition.deadline_type == "rooming_list_due" }
    [
      Section.new(key: "stay", label: "Stay", state: workspace.stay.state, detail: nil),
      Section.new(key: "inventory", label: "Nightly room block", state: workspace.inventory.state, detail: nil),
      Section.new(
        key: "rates", label: "Supplier rates", state: workspace.rates.state,
        detail: workspace.rates.authority
      ),
      Section.new(key: "deposits", label: "Deposits", state: deposit_state(workspace), detail: nil),
      Section.new(
        key: "deadlines", label: "Deadlines", state: deadline_state(workspace),
        detail: rooming ? rooming.due_label : "No rooming list recorded"
      ),
      Section.new(key: "terms", label: "Agreement terms", state: terms_state(workspace), detail: nil),
      Section.new(
        key: "confirmation", label: "Supplier confirmation",
        state: confirmation ? "Supplier confirmed" : "Not Supplier confirmed", detail: nil
      ),
      Section.new(
        key: "activation", label: "Activation",
        state: workspace.version.activation, detail: nil
      )
    ]
  end

  def hotel_blockers(workspace)
    blockers = []
    blockers << Blocker.new(code: :stay, message: "Record a supported Hotel stay.", target: :stay) unless workspace.stay.state == "Recorded"
    blockers << Blocker.new(code: :inventory, message: "Record a supported nightly room block.", target: :inventory) unless workspace.inventory.state == "Recorded"
    unless workspace.rates.state == "Recorded" && workspace.rates.authority == "Contracted"
      blockers << Blocker.new(
        code: :rates,
        message: "Each inventory night needs one ready contracted Supplier rate.",
        target: :rates
      )
    end
    if workspace.unassigned_deposits.any? || workspace.deposits.any? { |row| !row.thin }
      blockers << Blocker.new(code: :deposits, message: "Scheduled deposits must be supported thin deposits.", target: :deposits)
    end
    if workspace.unassigned_deadlines.any? || workspace.deadlines.any?(&:advanced)
      blockers << Blocker.new(
        code: :deadlines,
        message: "A recorded Deadline needs Hotel scope or uses an advanced shape.",
        target: :deadlines
      )
    end
    workspace.terms.each do |term|
      next if acceptable_term?(term)

      blockers << Blocker.new(
        code: :"term_#{term.kind}",
        message: "#{term.label} is not reviewed for this Hotel stay.",
        target: :terms
      )
    end
    blockers
  end

  def acceptable_term?(term)
    term.state.in?([ "Recorded", "Reviewed — none" ])
  end

  def typed_activation_attestations_safe?
    @version.arrangement_item_definitions.where.not(category: "lodging").none? &&
      @version.supplier_cost_sources.where(arrangement_item_id: nil).none? &&
      @version.supplier_commitment_trigger_definitions.none?
  end

  def other_lodging_blockers
    @version.arrangement_item_definitions
      .where(category: "lodging")
      .where.not(arrangement_item_id: @item.id)
      .order(:position, :id)
      .filter_map do |definition|
        item = @arrangement.arrangement_items.find(definition.arrangement_item_id)
        workspace = HotelAgreementWorkspace.new(
          agency: @agency, departure: @departure, arrangement: @arrangement,
          version: @version, item: item
        ).call
        next if hotel_blockers(workspace).empty?

        Blocker.new(
          code: :other_lodging_review,
          message: "#{definition.name} still needs Hotel review.",
          target: { kind: :hotel_review, item_id: item.id }
        )
      end
  end

  def readiness_blockers(readiness)
    readiness.blockers.map do |blocker|
      Blocker.new(
        code: blocker.code,
        message: hotel_readiness_message(blocker),
        target: hotel_readiness_target(blocker)
      )
    end.uniq { |entry| [ entry.code, entry.message, entry.target ] }
  end

  def hotel_readiness_message(blocker)
    case blocker.code
    when :lodging_agreement_unconfirmed
      "Record Supplier confirmation before activation."
    when :predecessor_not_governing, :copied_lineage_invalid
      "The copied Hotel agreement history needs attention before activation."
    when :items_missing, :occurrences_missing, :resources_missing, :incomplete_graph
      "The Supplier agreement structure is incomplete before activation."
    when :provider_inactive, :contracting_supplier_inactive
      "A Supplier used by this agreement is not active."
    when :management_undeclared, :pairs_incomplete, :pools_missing
      "Room inventory still needs operational setup before activation."
    when :supplying_supplier_mismatch, :opening_authority_incomplete
      "Room inventory authority needs attention before activation."
    when :item_coverage_missing
      "A retained service still needs Supplier cost coverage before activation."
    when :ready_definition_missing
      "A Supplier cost used for activation is not ready."
    when :cost_authority_ineligible
      "A Supplier cost used for activation has an ineligible Supplier or currency."
    when :carried_pool_omission_blocked
      "A carried room-capacity change must be reconciled before activation."
    when :trigger_incomplete, :confirmation_supplier_incompatible, :contracted_authority_invalid
      "A Supplier commitment rule needs Advanced Supplier planning before activation."
    when :cruise_agreement_unconfirmed, :cruise_contracted_rates_missing, :cruise_deposit_treatment_missing
      "A Cruise service on this version needs its Cruise review completed before activation."
    else
      "Advanced Supplier planning is required before activation."
    end
  end

  def hotel_readiness_target(blocker)
    item_id = blocker.path.to_s[/\Aitems\.([0-9a-f-]+)/, 1]
    if item_id && @version.arrangement_item_definitions.exists?(
      arrangement_item_id: item_id, category: "lodging"
    )
      return { kind: :hotel_review, item_id: item_id }
    end

    :activation
  end

  def elapsed_labels_for(workspace)
    at = Time.current
    deadline_ids = workspace.deadlines.map { |row| row.definition.id }
    deposit_ids = workspace.deposits.map { |row| row.definition.id }

    deadline_rows = MaterializeSupplierDeadlineDefinitionsAlreadyLocked.new(
      agency: @agency, actor: nil, arrangement: @arrangement, version: @version,
      activation: nil, departure: @departure, at: at
    ).preview_elapsed.select { |row| deadline_ids.include?(row[:definition].id) }

    deposit_rows = MaterializeSupplierDepositRequirementDefinitionsAlreadyLocked.new(
      agency: @agency, actor: nil, arrangement: @arrangement, version: @version,
      activation: nil, departure: @departure, at: at
    ).preview_elapsed.select { |row| deposit_ids.include?(row[:definition].id) }

    deadline_labels = deadline_rows.map do |row|
      definition = row[:definition]
      due = row[:calculated_at] || row[:calculated_on]
      "#{definition.display_label}: #{due}"
    end
    deposit_labels = deposit_rows.map do |row|
      due = row[:calculated_at] || row[:calculated_on]
      "Supplier deposit: #{due}"
    end
    deadline_labels + deposit_labels
  rescue AgencyCommand::Error
    []
  end

  def revision_allowed?(confirmation)
    confirmation.present? &&
      @departure.active? &&
      @arrangement.draft? &&
      @arrangement.governing_version_id.nil? &&
      @version.draft? &&
      @version.arrangement_item_definitions.exists?(category: "lodging")
  end

  def deposit_state(workspace)
    return "Needs attention" if workspace.unassigned_deposits.any? || workspace.deposits.any? { |row| !row.thin }
    return "No Supplier deposits recorded" if workspace.deposits.empty?

    "Recorded"
  end

  def deadline_state(workspace)
    return "Needs attention" if workspace.unassigned_deadlines.any? || workspace.deadlines.any?(&:advanced)
    return "No rooming list recorded" if workspace.deadlines.none? { |row| row.definition.deadline_type == "rooming_list_due" }

    "Recorded"
  end

  def terms_state(workspace)
    return "Needs attention" unless workspace.terms.all? { |term| acceptable_term?(term) }

    "Recorded"
  end
end
