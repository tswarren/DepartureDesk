# frozen_string_literal: true

class EvaluateServiceOfferPublicationReadiness
  Issue = Data.define(:field, :message)
  Result = Data.define(:ok, :issues)

  def initialize(agency:, version:)
    @agency = agency
    @version = version
  end

  def call
    issues = []
    departure = @version.departure
    unless departure.active?
      issues << Issue.new(field: :departure, message: "Publication requires an active Departure.")
    end

    if @version.owning_package_version_id.present?
      issues << Issue.new(field: :ownership, message: "Package-only services publish with their Package.")
    end

    unless @version.draft?
      issues << Issue.new(field: :status, message: "Only a draft version can be published.")
    end

    definition = @version.definition
    if definition.nil?
      issues << Issue.new(field: :definition, message: "Add a Client service definition.")
    elsif definition.m3_backed?
      issues.concat(m3_binding_issues)
    end

    issues.concat(choice_price_issues)
    issues.concat(standalone_price_issues) unless definition&.m3_backed? && bundled_via_package?

    Result.new(ok: issues.empty?, issues: issues)
  end

  private

  def bundled_via_package?
    false
  end

  def m3_binding_issues
    issues = []
    bindings = @version.source_bindings.includes(
      :supplier_arrangement_version, :arrangement_item_definition,
      :service_occurrence_definition, :supplier_resource_definition, :capacity_pool_definition
    ).to_a
    if bindings.empty?
      return [ Issue.new(field: :source, message: "Add an activated M3 source binding.") ]
    end

    required = bindings.select(&:required?)
    alternatives = bindings.select(&:alternative?).group_by(&:alternative_group_key)
    choice_gated = bindings.select(&:choice_gated?)

    required.each { |binding| issues.concat(binding_activation_issues(binding)) }
    alternatives.each_value do |group|
      eligible = group.select { |binding| binding_activation_issues(binding).empty? }
      if eligible.empty?
        issues << Issue.new(field: :source, message: "Each alternative group needs at least one activated eligible source.")
      end
    end
    choice_gated.each { |binding| issues.concat(binding_activation_issues(binding)) }
    issues
  end

  def binding_activation_issues(binding)
    issues = []
    version = binding.supplier_arrangement_version
    unless version&.activated?
      issues << Issue.new(field: :source, message: "Pin an activated Arrangement version for every M3-backed binding.")
      return issues
    end
    if binding.arrangement_item_definition.blank?
      issues << Issue.new(field: :source, message: "A source binding is missing its Item definition.")
    end
    issues
  end

  def choice_price_issues
    issues = []
    groups = @version.choice_groups.includes(:service_offer_choice_options).order(:position).to_a
    return issues if groups.empty?

    groups.each do |group|
      options = group.service_offer_choice_options.sort_by(&:position)
      if options.size < group.min_selections
        issues << Issue.new(field: :choices, message: "Choice group #{group.name} needs enough options for its minimum.")
      end
      options.each do |option|
        if option.price_effect_minor_units.nil?
          issues << Issue.new(
            field: :choices,
            message: "Enter an included price (0) or surcharge for #{option.name}."
          )
        end
      end
    end

    # At least one combination must be fully priced (all selected options have non-null effects).
    # With NULL options already flagged, structural min/max is enough when remaining options are priced.
    issues
  end

  def standalone_price_issues
    issues = []
    price = @version.price_definition
    if price.nil?
      issues << Issue.new(field: :price, message: "Add a Client price before publishing a standalone service.")
    end
    issues
  end
end
