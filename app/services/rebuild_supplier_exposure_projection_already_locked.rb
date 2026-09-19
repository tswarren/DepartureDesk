# frozen_string_literal: true

require "digest"
require "set"

# Rebuilds Arrangement exposure projection rows from authoritative sources.
# Callers must already hold Agency and Arrangement locks.
class RebuildSupplierExposureProjectionAlreadyLocked
  ComponentDraft = Data.define(
    :source_kind, :source_id, :qualification_band, :completeness,
    :qualification_reason, :gross_minor_units, :expected_commission_minor_units,
    :expected_net_minor_units, :currency, :source_fingerprint, :effective_at,
    :economic_cost_source_id
  )

  def initialize(agency:, arrangement:, version: nil, at: Time.current)
    @agency = agency
    @arrangement = arrangement
    @version = version
    @at = at
  end

  def call
    version = resolve_version!
    lock_existing_projection_rows!(version)
    @operating_currency = operating_currency_for(version)

    drafts = []
    drafts.concat(commitment_components(version))
    drafts.concat(cost_source_components(version))
    drafts = dedupe_alternative_bands(drafts)

    replace_components!(version, drafts)
    replace_summaries!(version, drafts)
    {
      components: SupplierExposureComponent.where(supplier_arrangement_id: @arrangement.id).order(:id),
      summaries: SupplierExposureSummary.where(supplier_arrangement_id: @arrangement.id).order(:id)
    }
  end

  private

  def resolve_version!
    version = @version ||
      @arrangement.governing_version ||
      @arrangement.versions.order(version_number: :desc, id: :desc).first
    if version.nil?
      raise AgencyCommand::Error.new("Arrangement has no version for exposure rebuild.", code: :invalid_state)
    end

    @agency.supplier_arrangement_versions.lock.find(version.id)
  end

  def operating_currency_for(version)
    version.departure&.operating_currency ||
      @arrangement.departure.operating_currency
  end

  def lock_existing_projection_rows!(version)
    SupplierExposureComponent.where(
      agency_id: @agency.id,
      supplier_arrangement_id: @arrangement.id
    ).order(:source_kind, :source_id, :qualification_band, :currency, :id).lock.load
    SupplierExposureSummary.where(
      agency_id: @agency.id,
      supplier_arrangement_id: @arrangement.id
    ).order(:qualification_band, :currency, :id).lock.load
    SupplierExposureSourceQualification.where(
      agency_id: @agency.id,
      supplier_arrangement_id: @arrangement.id,
      supplier_arrangement_version_id: version.id
    ).order(:source_kind, :source_id, :id).lock.load
  end

  def commitment_components(version)
    commitments = SupplierCommitment.with_current_disposition_state.where(
      agency_id: @agency.id,
      supplier_arrangement_id: @arrangement.id,
      supplier_arrangement_version_id: version.id
    ).order(:id).to_a.select(&:open_state?)

    commitments.filter_map do |commitment|
      next if commitment.deposit_requirement?
      next if commitment.amount_minor_units.nil?

      ComponentDraft.new(
        source_kind: "supplier_commitment",
        source_id: commitment.id,
        qualification_band: "guaranteed",
        completeness: "known",
        qualification_reason: "open_#{commitment.opening_kind}_commitment",
        gross_minor_units: commitment.amount_minor_units,
        expected_commission_minor_units: 0,
        expected_net_minor_units: commitment.amount_minor_units,
        currency: commitment.currency,
        source_fingerprint: fingerprint(
          "commitment", commitment.id, commitment.amount_minor_units, commitment.calculation_snapshot
        ),
        effective_at: commitment.opened_at,
        economic_cost_source_id: commitment.supplier_cost_source_id
      )
    end
  end

  def cost_source_components(version)
    forecast = EvaluateSupplierCostForecast.new(
      agency: @agency,
      departure: @arrangement.departure_id,
      arrangement: @arrangement,
      version:
    ).call(isolated: false)
    arrangement_result = forecast.arrangements.find { |row| row.arrangement_id == @arrangement.id }
    return [] if arrangement_result.nil?

    qualifications = SupplierExposureSourceQualification.where(
      agency_id: @agency.id,
      supplier_arrangement_id: @arrangement.id,
      supplier_arrangement_version_id: version.id,
      source_kind: "supplier_cost_source"
    ).index_by(&:source_id)

    open_cost_source_ids = open_commitment_cost_source_ids(version)

    arrangement_result.sources.flat_map do |source|
      build_cost_source_drafts(source, qualifications[source.source_id], open_cost_source_ids)
    end
  end

  def build_cost_source_drafts(source, qualification, open_cost_source_ids)
    drafts = []
    currency = source.currency.presence || @operating_currency
    effective_at = @at
    already_guaranteed_by_commitment = open_cost_source_ids.include?(source.source_id)

    unless source.complete
      drafts << ComponentDraft.new(
        source_kind: "supplier_cost_source",
        source_id: source.source_id,
        qualification_band: "forecast",
        completeness: source.definition_id.present? ? "incomplete" : "unknown",
        qualification_reason: source.definition_id.present? ? "cost_forecast_incomplete" : "cost_forecast_unknown",
        gross_minor_units: nil,
        expected_commission_minor_units: nil,
        expected_net_minor_units: nil,
        currency:,
        source_fingerprint: fingerprint("cost", source.source_id, "incomplete", source.selected_stage),
        effective_at:,
        economic_cost_source_id: source.source_id
      )
      return drafts
    end

    totals = source.totals
    drafts << ComponentDraft.new(
      source_kind: "supplier_cost_source",
      source_id: source.source_id,
      qualification_band: "forecast",
      completeness: "known",
      qualification_reason: "cost_forecast_#{source.selected_stage}",
      gross_minor_units: totals.forecast_supplier_cost_minor_units,
      expected_commission_minor_units: totals.expected_commission_minor_units,
      expected_net_minor_units: totals.expected_net_cost_after_commission_minor_units,
      currency:,
      source_fingerprint: fingerprint(
        "cost", source.source_id, source.selected_stage, source.definition_id,
        totals.forecast_supplier_cost_minor_units, totals.expected_commission_minor_units
      ),
      effective_at:,
      economic_cost_source_id: source.source_id
    )

    estimate_stage = source.selected_stage.to_s.include?("estimate")

    # An open monetary commitment for this cost source already carries the
    # guaranteed position; do not also emit qualified/contingent gross.
    if already_guaranteed_by_commitment
      return drafts
    end

    if qualification&.guaranteed?
      drafts << ComponentDraft.new(
        source_kind: "supplier_cost_source",
        source_id: source.source_id,
        qualification_band: "guaranteed",
        completeness: "known",
        qualification_reason: qualification.qualification_reason,
        gross_minor_units: totals.forecast_supplier_cost_minor_units,
        expected_commission_minor_units: totals.expected_commission_minor_units,
        expected_net_minor_units: totals.expected_net_cost_after_commission_minor_units,
        currency:,
        source_fingerprint: fingerprint(
          "qualified", source.source_id, qualification.id, totals.forecast_supplier_cost_minor_units
        ),
        effective_at: qualification.recorded_at,
        economic_cost_source_id: source.source_id
      )
    elsif !estimate_stage
      drafts << ComponentDraft.new(
        source_kind: "supplier_cost_source",
        source_id: source.source_id,
        qualification_band: "contingent",
        completeness: "known",
        qualification_reason: "contracted_awaiting_qualifying_trigger",
        gross_minor_units: totals.forecast_supplier_cost_minor_units,
        expected_commission_minor_units: totals.expected_commission_minor_units,
        expected_net_minor_units: totals.expected_net_cost_after_commission_minor_units,
        currency:,
        source_fingerprint: fingerprint(
          "contingent", source.source_id, source.definition_id, totals.forecast_supplier_cost_minor_units
        ),
        effective_at:,
        economic_cost_source_id: source.source_id
      )
    end

    drafts
  end

  def open_commitment_cost_source_ids(version)
    SupplierCommitment.with_current_disposition_state.where(
      agency_id: @agency.id,
      supplier_arrangement_id: @arrangement.id,
      supplier_arrangement_version_id: version.id
    ).where.not(supplier_cost_source_id: nil)
      .where.not(amount_minor_units: nil)
      .order(:id).to_a
      .select(&:open_state?)
      .map(&:supplier_cost_source_id)
      .to_set
  end

  # Same economic source must not contribute guaranteed + contingent liabilities,
  # and must not double-count guaranteed across commitment and cost-source rows.
  def dedupe_alternative_bands(drafts)
    by_economic = drafts.group_by { |draft| economic_key(draft) }
    by_economic.flat_map do |_key, group|
      guaranteed = preferred_guaranteed(group)
      contingent = group.find { |draft| draft.qualification_band == "contingent" }
      forecasts = group.select { |draft| draft.qualification_band == "forecast" }

      selected = []
      selected << guaranteed if guaranteed
      selected << contingent if contingent && guaranteed.nil?
      selected.concat(forecasts)
      selected
    end
  end

  def economic_key(draft)
    if draft.economic_cost_source_id.present?
      [ "cost_source", draft.economic_cost_source_id, draft.currency ]
    else
      [ draft.source_kind, draft.source_id, draft.currency ]
    end
  end

  def preferred_guaranteed(group)
    guaranteed = group.select { |draft| draft.qualification_band == "guaranteed" }
    return nil if guaranteed.empty?

    guaranteed.find { |draft| draft.source_kind == "supplier_commitment" } || guaranteed.first
  end

  def replace_components!(version, drafts)
    existing = SupplierExposureComponent.where(
      agency_id: @agency.id, supplier_arrangement_id: @arrangement.id
    ).index_by { |row| [ row.source_kind, row.source_id, row.qualification_band, row.currency ] }

    keep_keys = []
    drafts.each do |draft|
      key = [ draft.source_kind, draft.source_id, draft.qualification_band, draft.currency ]
      keep_keys << key
      attrs = {
        agency_id: @agency.id,
        departure_id: @arrangement.departure_id,
        supplier_arrangement_id: @arrangement.id,
        supplier_arrangement_version_id: version.id,
        qualification_band: draft.qualification_band,
        completeness: draft.completeness,
        source_kind: draft.source_kind,
        source_id: draft.source_id,
        qualification_reason: draft.qualification_reason,
        gross_minor_units: draft.gross_minor_units,
        expected_commission_minor_units: draft.expected_commission_minor_units,
        expected_net_minor_units: draft.expected_net_minor_units,
        currency: draft.currency,
        source_fingerprint: draft.source_fingerprint,
        effective_at: draft.effective_at,
        rebuilt_at: @at
      }
      row = existing[key]
      if row
        row.lock!
        row.update!(attrs.except(
          :agency_id, :departure_id, :supplier_arrangement_id, :source_kind, :source_id
        ))
      else
        SupplierExposureComponent.create!(attrs)
      end
    end

    existing.each do |key, row|
      next if keep_keys.include?(key)

      row.destroy!
    end
  end

  def replace_summaries!(version, drafts)
    required_deposits = required_deposit_by_currency(version)
    grouped = drafts.group_by { |draft| [ draft.qualification_band, draft.currency ] }
    existing = SupplierExposureSummary.where(
      agency_id: @agency.id, supplier_arrangement_id: @arrangement.id
    ).index_by { |row| [ row.qualification_band, row.currency ] }

    summary_keys = grouped.keys.to_set
    required_deposits.each_key { |currency| summary_keys << [ "guaranteed", currency ] }

    keep_keys = []
    summary_keys.each do |band, currency|
      group = grouped[[ band, currency ]] || []
      deposit = (band == "guaranteed" ? required_deposits[currency].to_i : nil)
      next if group.empty? && deposit.to_i.zero?

      keep_keys << [ band, currency ]
      completeness, gross, commission, net = if group.empty?
        [ "known", 0, 0, 0 ]
      else
        summarize_amounts(group)
      end
      attrs = {
        agency_id: @agency.id,
        departure_id: @arrangement.departure_id,
        supplier_arrangement_id: @arrangement.id,
        supplier_arrangement_version_id: version.id,
        qualification_band: band,
        completeness:,
        currency:,
        gross_minor_units: gross,
        expected_commission_minor_units: commission,
        expected_net_minor_units: net,
        required_deposit_minor_units: deposit,
        component_count: group.size,
        rebuilt_at: @at
      }
      row = existing[[ band, currency ]]
      if row
        row.lock!
        row.update!(attrs.except(:agency_id, :departure_id, :supplier_arrangement_id))
      else
        SupplierExposureSummary.create!(attrs)
      end
    end

    existing.each do |key, row|
      next if keep_keys.include?(key)

      row.destroy!
    end
  end

  def summarize_amounts(group)
    return [ "unknown", nil, nil, nil ] if group.empty?

    if group.all? { |draft| draft.completeness == "known" }
      [
        "known",
        group.sum(&:gross_minor_units),
        group.sum(&:expected_commission_minor_units),
        group.sum(&:expected_net_minor_units)
      ]
    elsif group.any? { |draft| draft.completeness == "known" }
      known = group.select { |draft| draft.completeness == "known" }
      [
        "partially_known",
        known.sum(&:gross_minor_units),
        known.sum(&:expected_commission_minor_units),
        known.sum(&:expected_net_minor_units)
      ]
    elsif group.any? { |draft| draft.completeness == "incomplete" }
      [ "incomplete", nil, nil, nil ]
    else
      [ "unknown", nil, nil, nil ]
    end
  end

  def required_deposit_by_currency(version)
    SupplierCommitment.with_current_disposition_state.where(
      agency_id: @agency.id,
      supplier_arrangement_id: @arrangement.id,
      supplier_arrangement_version_id: version.id,
      opening_kind: "deposit_requirement"
    ).order(:id).to_a.select(&:open_state?).each_with_object(Hash.new(0)) do |commitment, memo|
      currency = commitment.currency.presence ||
        commitment.supplier_deposit_requirement_tranche&.currency
      next if currency.blank?

      amount = commitment.supplier_deposit_requirement_tranche&.current_amount_minor_units ||
        commitment.amount_minor_units
      memo[currency] += amount.to_i
    end
  end

  def fingerprint(*parts)
    Digest::SHA256.hexdigest(parts.compact.join("|"))[0, 64]
  end
end
