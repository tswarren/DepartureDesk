# frozen_string_literal: true

# Presentation statuses for Cruise setup. This is not a readiness or completion
# evaluator. It reads underlying facts only: cabin rows, rate posture, the
# current agreement confirmation, activation readiness blockers, and whether
# the Cruise activation review can post. It does not read overview status
# labels, recommended next actions, or maintenance steps.
class CompileCruiseSetupNavigation
  Area = Data.define(:key, :label, :status)
  AttentionItem = Data.define(:code, :message, :destination, :resource_id)
  Result = Data.define(:areas, :attention_items)

  AREAS = [
    [ :sailing, "Sailing" ],
    [ :cabins, "Cabin inventory" ],
    [ :rates, "Supplier rates" ],
    [ :agreement, "Agreement" ],
    [ :review, "Review & activate" ]
  ].freeze

  SCHEDULED_ATTENTION_POSTURES = %i[contracted_working working missing].freeze
  RECOGNIZED_ATTENTION_CODES = %i[
    opening_authority_incomplete
    cruise_contracted_rates_missing
    cruise_agreement_unconfirmed
    cruise_deposit_treatment_missing
  ].freeze

  def initialize(agency:, arrangement:, shape:, summary: nil)
    @agency = agency
    @arrangement = arrangement
    @shape = shape
    @summary = summary
  end

  def call
    return advanced_result unless @shape.compatible?

    version = @shape.version
    summary = @summary
    rows = if summary
      summary.cabin_rows
    else
      CompileCruiseCompositionSummary.new(
        agency: @agency,
        arrangement: @arrangement,
        shape: @shape
      ).navigation_cabin_rows
    end
    review = CompileCruiseActivationReview.new(
      agency: @agency,
      arrangement: @arrangement,
      version: version,
      presentation: false,
      readiness: summary&.activation_readiness
    ).call
    codes = review.blockers.map(&:code)
    confirmation = version.supplier_arrangement_cruise_agreement_confirmations.find_by(current: true)
    statuses = {
      sailing: "Complete",
      cabins: cabin_status(rows, version),
      rates: rates_status(rows, codes),
      agreement: agreement_status(confirmation, codes),
      review: review_status(version, codes, review)
    }

    Result.new(
      areas: AREAS.map { |key, label| Area.new(key: key, label: label, status: statuses.fetch(key)) },
      attention_items: attention_items(review, rows, statuses[:rates], confirmation, version)
    )
  end

  private

  def advanced_result
    Result.new(
      areas: AREAS.map { |key, label| Area.new(key: key, label: label, status: "Advanced") },
      attention_items: [
        AttentionItem.new(
          code: :advanced_structure,
          message: "This Arrangement uses an advanced structure that Cruise setup cannot summarize without discarding information.",
          destination: :advanced_planning,
          resource_id: nil
        )
      ]
    )
  end

  def cabin_status(rows, version)
    return "Not started" if rows.empty?

    definitions = version.capacity_pool_definitions.includes(:capacity_pool).to_a
    return "Needs attention" if definitions.empty?
    return "Needs attention" if definitions.any? { |definition|
      definition.capacity_pool.numeric_inventory? && definition.proposed_opening_quantity.to_i <= 0
    }

    "Complete"
  end

  def rates_status(rows, _codes)
    return "Advanced" if rows.any? && rows.all?(&:advanced_rates)
    return "Not started" if rows.empty? || rows.all? { |row| row.rate_posture == :missing }

    incomplete = rows.any? { |row| %i[contracted_working working estimated missing].include?(row.rate_posture) }
    return "Needs attention" if incomplete
    return "Complete" if rows.all? { |row| %i[contracted_ready contracted_usable].include?(row.rate_posture) } && rows.none?(&:advanced_rates)

    "Needs attention"
  end

  def agreement_status(confirmation, codes)
    return "Not started" if confirmation.nil?

    if codes.include?(:cruise_agreement_unconfirmed) || codes.include?(:cruise_deposit_treatment_missing)
      return "Needs attention"
    end

    return "Complete" if confirmation.status == "confirmed"

    "Needs attention"
  end

  def review_status(version, codes, review)
    if version&.activated? && version.id == @arrangement.governing_version_id
      return "Active"
    end
    return "Ready to review" if review.activation_confirmable?
    if codes.any?
      return "Needs attention" if codes.any? { |code| RECOGNIZED_ATTENTION_CODES.include?(code) }

      return "Requires Advanced"
    end
    return "Ready to review" if review.cruise_post_allowed?

    "Requires Advanced"
  end

  def attention_items(review, rows, rates_status, confirmation, version)
    estimate_only = rates_status == "Needs attention" && rows.none? { |row|
      SCHEDULED_ATTENTION_POSTURES.include?(row.rate_posture)
    }

    review.blockers.filter_map do |blocker|
      case blocker.code
      when :opening_authority_incomplete
        next if positive_opening_quantity?(version, blocker)

        AttentionItem.new(
          code: blocker.code,
          message: blocker.message,
          destination: blocker.resource_id.present? ? :cabin_editor : :cabin_card,
          resource_id: blocker.resource_id
        )
      when :cruise_contracted_rates_missing
        next unless rates_status == "Needs attention"
        next if estimate_only
        next if reviewable_contracted_rate?(blocker, rows)

        row = rows.find { |candidate| candidate.resource_id == blocker.resource_id }
        AttentionItem.new(
          code: blocker.code,
          message: blocker.message,
          destination: row.nil? || row.advanced_rates ? :advanced_costs : :supplier_rates,
          resource_id: blocker.resource_id
        )
      when :cruise_agreement_unconfirmed
        next if confirmation.nil?

        AttentionItem.new(
          code: blocker.code,
          message: blocker.message,
          destination: :agreement,
          resource_id: nil
        )
      when :cruise_deposit_treatment_missing
        AttentionItem.new(
          code: blocker.code,
          message: blocker.message,
          destination: :agreement,
          resource_id: nil
        )
      end
    end.tap do |items|
      next if review.blockers.all? { |blocker| RECOGNIZED_ATTENTION_CODES.include?(blocker.code) }

      items << AttentionItem.new(
        code: :activation_readiness,
        message: "Activation readiness still needs review.",
        destination: :activation,
        resource_id: nil
      )
    end
  end

  def positive_opening_quantity?(version, blocker)
    return false if blocker.resource_id.blank?

    version.capacity_pool_definitions.includes(:capacity_pool).any? { |definition|
      definition.supplier_resource_id == blocker.resource_id &&
        definition.capacity_pool.numeric_inventory? &&
        definition.proposed_opening_quantity.to_i.positive?
    }
  end

  def reviewable_contracted_rate?(blocker, rows)
    row = rows.find { |candidate| candidate.resource_id == blocker.resource_id }
    row && %i[contracted_usable contracted_ready].include?(row.rate_posture)
  end
end
