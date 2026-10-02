# frozen_string_literal: true

class CompileHotelActivationReview
  Blocker = Data.define(:code, :message, :target)
  Section = Data.define(:key, :label, :state, :detail)
  Result = Data.define(
    :workspace, :readiness, :sections, :blockers,
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
    blockers = hotel_blockers + readiness_blockers(readiness)
    hotel_clear = hotel_blockers.empty?
    draft = @version.draft? && @arrangement.editable_version&.id == @version.id
    Result.new(
      workspace: workspace,
      readiness: readiness,
      sections: sections_for(workspace, confirmation),
      blockers: blockers,
      confirmation_allowed: draft && confirmation.nil? && hotel_clear,
      revision_allowed: revision_allowed?(confirmation),
      activation_allowed: draft && confirmation.present? && hotel_clear && readiness.ready?,
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
    if workspace.deadlines.any?(&:advanced)
      blockers << Blocker.new(code: :deadlines, message: "A Deadline on this stay uses an advanced shape.", target: :deadlines)
    end
    workspace.terms.each do |term|
      next if acceptable_term?(term)

      blockers << Blocker.new(
        code: :"term_#{term.kind}",
        message: "#{term.label} is not recorded for this Hotel stay.",
        target: :terms
      )
    end
    blockers
  end

  def acceptable_term?(term)
    term.state.in?([ "Recorded", "Reviewed — none" ])
  end

  def readiness_blockers(readiness)
    readiness.blockers.map do |blocker|
      Blocker.new(code: blocker.code, message: blocker.message, target: :activation)
    end
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
    return "Needs attention" if workspace.deadlines.any?(&:advanced)
    return "No rooming list recorded" if workspace.deadlines.none? { |row| row.definition.deadline_type == "rooming_list_due" }

    "Recorded"
  end

  def terms_state(workspace)
    return "Needs attention" unless workspace.terms.all? { |term| acceptable_term?(term) }

    "Recorded"
  end
end
