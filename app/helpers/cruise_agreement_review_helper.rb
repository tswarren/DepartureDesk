# frozen_string_literal: true

module CruiseAgreementReviewHelper
  def cruise_agreement_focused?(key)
    @focus.to_s == key.to_s
  end

  def cruise_agreement_marked?(key)
    @highlight.to_s == key.to_s
  end

  def cruise_marked_heading(tag, key, text, **attributes)
    options = attributes.merge(id: key, tabindex: "-1")
    options[:autofocus] = true if cruise_agreement_marked?(key)
    content_tag(tag, text, options)
  end

  def cruise_calendar_date(value)
    return nil if value.blank?

    date = value.is_a?(Date) ? value : Date.iso8601(value.to_s)
    date.strftime("%B %-d, %Y")
  rescue ArgumentError, TypeError
    value.to_s
  end

  def cruise_minor_amount_field(minor_units, currency)
    return "" if minor_units.nil?

    Money.new(minor_units, currency.to_s.upcase).format(symbol: false, thousands_separator: false)
  end

  def cruise_fixed_due_date(definition)
    parameters = definition.rule_parameters
    return nil unless parameters.is_a?(Hash)

    parameters["date"].presence || parameters[:date].presence
  end

  def cruise_suggested_deposit_due_on
    CruiseInitialDepositDueDate.suggested_on(@agreement_confirmation&.group_creation_date)
  end

  def cruise_preset_initial_deposit?(row)
    row.compatible? && row.template == "initial_deposit" && row.definition.rule_shape == "fixed_date"
  end

  def cruise_preset_deadline?(row, template)
    row.compatible? && row.template == template && row.definition.rule_shape == "fixed_date"
  end

  def cruise_opening_deposit_sentence(definition)
    evaluated = SupplierDepositAmountEvaluator.call(
      definition: definition,
      version: @supplier_arrangement_version,
      arrangement: @supplier_arrangement,
      mode: :preview
    )
    return "No opening quantity applies" if evaluated[:quantity_not_tracked]

    currency = definition.currency
    quantity = evaluated.dig(:inputs, "quantity")
    rate = Money.new(definition.rate_minor_units, currency).format
    total = Money.new(evaluated.fetch(:amount_minor_units), currency).format
    sentence = "#{rate} per opening cabin × #{quantity} #{'cabin'.pluralize(quantity)} = #{total}"
    excluded = Array(evaluated.dig(:inputs, "excluded_pools"))
    return sentence if excluded.empty?

    "#{sentence}. On request and externally managed cabins are not included."
  rescue SupplierDepositAmountEvaluator::IncompleteCalculation
    nil
  end

  def cruise_deposit_pool_ids(definition)
    return Array(@cabin_pool_ids) if definition.nil?

    definition.supplier_deposit_requirement_definition_coverage_links.filter_map(&:capacity_pool_id)
  end

  def cruise_posted_deposit
    params[:cruise_deposit].presence
  end

  def cruise_posted_deadline
    params[:cruise_deadline].presence
  end

  def cruise_cancellation_steps
    @agreement_terms.select(&:cancellation_step?).sort_by(&:position)
  end

  def cruise_term(term_type)
    @agreement_terms.find { |term| term.term_type == term_type }
  end

  def cruise_status_badge(label, tone)
    tone = "neutral" unless %w[success neutral].include?(tone.to_s)
    tag.span(label, class: "dd-badge dd-badge--#{tone}")
  end

  def cruise_confirmation_recorded_on(confirmation)
    confirmation.confirmed_at.in_time_zone(confirmation.agency.default_timezone).strftime("%B %-d, %Y")
  end

  def cruise_agreement_prior_confirmations(confirmation)
    return [] if confirmation.nil? || @supplier_arrangement_version.nil?

    @supplier_arrangement_version.supplier_arrangement_cruise_agreement_confirmations
      .where(current: false)
      .includes(:confirmed_by)
      .order(created_at: :desc)
      .to_a
  end

  def cruise_supplemental_deposit_treatment_pending?(confirmation)
    return false unless confirmation&.confirmed? && confirmation.deposit_treatment.blank?

    version = @supplier_arrangement_version
    predecessor = version&.copied_from
    return false unless predecessor

    predecessor_ids = predecessor.supplier_resource_definitions.map(&:supplier_resource_id)
    version.supplier_resource_definitions.any? { |definition|
      predecessor_ids.exclude?(definition.supplier_resource_id)
    }
  end

  def cruise_row_link(label, path)
    link_to(label, path, class: "dd-button dd-button--secondary dd-button--small")
  end

  def cruise_forward_link(label, path)
    link_to(label, path, class: "dd-forward-link")
  end
end
