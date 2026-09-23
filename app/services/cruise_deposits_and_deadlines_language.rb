# frozen_string_literal: true

# Staff-facing labels for typed Cruise deposit amount shapes and amount summaries.
# Presentation only — does not change M3E persistence or evaluator semantics.
module CruiseDepositsAndDeadlinesLanguage
  module_function

  def amount_shape_label(amount_shape, quantity_basis: nil)
    shape = amount_shape.to_s
    basis = quantity_basis.to_s

    case shape
    when "fixed_amount"
      "Fixed amount"
    when "quantity_times_rate"
      case basis
      when "capacity_pool_units" then "Amount per initially blocked cabin"
      when "explicit" then "Amount per explicit quantity"
      else "Amount × quantity"
      end
    when "cumulative_target"
      case basis
      when "capacity_pool_units" then "Cumulative amount per retained cabin"
      else "Cumulative target"
      end
    when "percentage_of_cost_sources"
      "Percentage of cost sources"
    else
      shape.tr("_", " ").presence&.capitalize || "Amount"
    end
  end

  def amount_label_for(definition, currency:)
    code = (definition.currency.presence || currency).to_s.upcase

    case definition.amount_shape.to_s
    when "fixed_amount"
      "Fixed deposit of #{format_minor(definition.fixed_amount_minor_units, code)}"
    when "quantity_times_rate"
      rate = format_minor(definition.rate_minor_units, code)
      case definition.quantity_basis.to_s
      when "capacity_pool_units"
        "#{rate} per initially blocked cabin"
      when "explicit"
        "#{rate} × #{definition.explicit_quantity}"
      else
        "#{rate} × quantity"
      end
    when "cumulative_target"
      if definition.quantity_basis.to_s == "capacity_pool_units" && definition.rate_minor_units.present?
        "#{format_minor(definition.rate_minor_units, code)} per retained cabin, less credited earlier deposits"
      else
        "Cumulative target #{format_minor(definition.target_amount_minor_units, code)}"
      end
    else
      CruiseDepositTemplateSupport.amount_sentence(definition, currency: code)
    end
  end

  def deposit_semantic_type_label(template)
    case template.to_s
    when "initial_deposit" then "Initial"
    when "final_deposit" then "Final"
    else "Other"
    end
  end

  def deadline_semantic_type_label(kind)
    kind.to_s == "actionable" ? "Action required" : "Informational"
  end

  def format_minor(minor_units, currency)
    return "—" if minor_units.nil?

    Money.new(minor_units, currency.to_s.upcase).format
  end
end
