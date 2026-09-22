# frozen_string_literal: true

module CompositionAccess
  OUTCOMES = %w[supplier pricing proposal publication].freeze
  RETURN_TARGETS = %w[services suppliers package review].freeze
  OUTCOME_LABELS = {
    "supplier" => "Supplier readiness",
    "pricing" => "Pricing review",
    "proposal" => "Client proposal preparation",
    "publication" => "Publication readiness"
  }.freeze

  private

  def require_composition_access!
    raise ActiveRecord::RecordNotFound unless Current.agency_user&.permitted?(:manage_departures)
  end

  def ensure_composable_departure!
    return if @departure.draft? || @departure.active?

    redirect_to departure_path(@departure)
  end

  def composition_outcome
    raw = params[:outcome].to_s
    raw = "proposal" if raw == "preview"
    raw.presence_in(OUTCOMES)
  end

  def composition_return_to
    params[:return_to].to_s.presence_in(RETURN_TARGETS)
  end

  def composition_context_params(extra = {})
    {
      outcome: defined?(@outcome) && !@outcome.nil? ? @outcome : composition_outcome,
      package_id: defined?(@package_id) ? @package_id : validated_composition_package_id
    }.merge(extra).compact_blank
  end

  def validated_composition_package_id
    id = params[:package_id].presence
    return if id.blank?

    package = Current.agency.packages.find_by(id: id, departure_id: @departure.id)
    raise ActiveRecord::RecordNotFound if package.nil?

    package.id
  end

  def composition_path_for_return(return_to = composition_return_to)
    case return_to
    when "services" then services_departure_composition_path(@departure, composition_context_params)
    when "suppliers" then suppliers_departure_composition_path(@departure, composition_context_params)
    when "package" then package_departure_composition_path(@departure, composition_context_params)
    when "review" then review_departure_composition_path(@departure, composition_context_params)
    else services_departure_composition_path(@departure, composition_context_params)
    end
  end

  def builder_compatibility_redirect_location
    work_on = params[:work_on].to_s
    package_id = begin
      validated_composition_package_id
    rescue ActiveRecord::RecordNotFound
      nil
    end
    ctx = { package_id: package_id }.compact

    case work_on
    when "preview"
      review_departure_composition_path(@departure, ctx.merge(outcome: "proposal"))
    when "supplier"
      suppliers_departure_composition_path(@departure, ctx.merge(outcome: "supplier"))
    when "pricing"
      package_departure_composition_path(@departure, ctx.merge(outcome: "pricing"))
    else
      departure_composition_path(@departure, ctx)
    end
  end
end
