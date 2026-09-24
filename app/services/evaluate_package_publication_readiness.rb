# frozen_string_literal: true

class EvaluatePackagePublicationReadiness
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
    unless @version.draft?
      issues << Issue.new(field: :status, message: "Only a draft version can be published.")
    end

    inclusions = @version.inclusions.includes(service_offer_version: [
      :definition, :price_definition, :source_bindings,
      { choice_groups: :service_offer_choice_options }
    ]).order(:position).to_a

    if inclusions.empty?
      issues << Issue.new(field: :inclusions, message: "Add at least one included service.")
    end

    inclusions.each do |inclusion|
      sov = inclusion.service_offer_version
      if sov.owning_package_version_id == @version.id
        if sov.draft?
          issues.concat(owned_service_issues(sov))
        elsif !sov.published?
          issues << Issue.new(field: :inclusions, message: "Owned services must be draft or already published with this Package.")
        end
      else
        unless sov.published?
          issues << Issue.new(field: :inclusions, message: "Reusable included services must already be published.")
        end
      end
    end

    price = @version.price_definition
    if price.nil?
      issues << Issue.new(field: :price, message: "Add a Package price method before publishing.")
    elsif price.service_sum?
      inclusions.select(&:included?).each do |inclusion|
        next if inclusion.service_offer_version.price_definition.present?

        issues << Issue.new(field: :price, message: "Service-sum Packages need a price on every included service.")
      end
    end

    issues.concat(choice_combination_issues(inclusions))
    Result.new(ok: issues.empty?, issues: issues.uniq { |issue| [ issue.field, issue.message ] })
  end

  private

  def owned_service_issues(sov)
    EvaluateServiceOfferPublicationReadiness.new(agency: @agency, version: sov).call.issues.reject do |issue|
      issue.field == :ownership || issue.field == :departure ||
        (issue.field == :price && @version.price_definition&.bundled?)
    end
  end

  def choice_combination_issues(inclusions)
    issues = []
    inclusions.each do |inclusion|
      next if inclusion.optional?

      sov = inclusion.service_offer_version
      sov.choice_groups.includes(:service_offer_choice_options).each do |group|
        options = group.service_offer_choice_options
        if options.size < group.min_selections
          issues << Issue.new(field: :choices, message: "Choice group #{group.name} needs enough options.")
        end
        options.each do |option|
          decision = CruiseCategoryOptionPrice.call(option: option, version: sov)
          if decision.status == :missing_base_price
            issues << Issue.new(field: :choices, message: "Enter the category price for #{option.name}.")
          elsif decision.status == :incomplete && option.price_effect_minor_units.nil?
            issues << Issue.new(field: :choices, message: "Enter an included price (0) or surcharge for #{option.name}.")
          end
        end
      end
    end
    issues
  end
end
