# frozen_string_literal: true

class EvaluateDepartureBuilderReadiness
  Finding = Data.define(
    :group, :code, :state, :message, :route_name, :route_params, :package_id, :service_offer_id
  ) do
    AREA_BY_CODE = {
      no_components: "services",
      no_package: "package",
      empty_package: "package",
      undecided_fulfillment: "suppliers",
      package_price_missing: "package",
      component_price_pending: "package",
      departure_not_active: "review",
      standalone_not_ready: "review",
      package_not_ready: "review"
    }.freeze

    # Declared per finding code — not derived from affected_area alone.
    OUTCOMES_BY_CODE = {
      no_components: %w[supplier pricing proposal publication],
      no_package: %w[pricing proposal],
      empty_package: %w[supplier pricing proposal],
      undecided_fulfillment: %w[supplier],
      package_price_missing: %w[pricing proposal],
      component_price_pending: %w[pricing proposal],
      departure_not_active: %w[publication],
      standalone_not_ready: %w[publication],
      package_not_ready: %w[publication]
    }.freeze

    def affected_area
      AREA_BY_CODE.fetch(code.to_sym) { area_for_group }
    end

    def applicable_outcomes
      OUTCOMES_BY_CODE.fetch(code.to_sym) do
        case affected_area
        when "services" then %w[supplier pricing proposal]
        when "suppliers" then %w[supplier]
        when "package" then %w[pricing proposal]
        when "review" then %w[publication]
        else %w[supplier pricing proposal publication]
        end
      end
    end

    def applicable_to?(outcome)
      raw = outcome.to_s
      raw = "proposal" if raw == "preview"
      return true if raw.blank?

      applicable_outcomes.include?(raw)
    end

    private

    def area_for_group
      case group
      when "Itinerary and Package" then "services"
      when "Supplier support" then "suppliers"
      when "Pricing and Client terms" then "package"
      when "Ready to publish" then "review"
      else "services"
      end
    end
  end
  Result = Data.define(:findings)

  GROUPS = [
    "Itinerary and Package",
    "Supplier support",
    "Pricing and Client terms",
    "Ready to publish"
  ].freeze

  def initialize(agency:, departure:)
    @agency = agency
    @departure = departure
  end

  def call
    Result.new(findings: GROUPS.flat_map { |group| findings_for(group) })
  end

  private

  def findings_for(group)
    case group
    when "Itinerary and Package" then itinerary_findings
    when "Supplier support" then supplier_findings
    when "Pricing and Client terms" then pricing_findings
    when "Ready to publish" then publish_findings
    else []
    end
  end

  def packages
    @packages ||= @departure.packages.includes(versions: { inclusions: { service_offer_version: :definition } }).to_a
  end

  def editable_packages
    @editable_packages ||= packages.select { |package| package.editable_draft_version.present? }
  end

  def unowned_offers
    @unowned_offers ||= @departure.service_offers.includes(versions: :definition).select do |offer|
      version = offer.editable_draft_version
      version&.draft? && version.owning_package_version_id.nil?
    end
  end

  def itinerary_findings
    findings = []
    if editable_packages.empty? && unowned_offers.empty?
      findings << finding(
        "Itinerary and Package", :no_components, :incomplete,
        "Add anything Clients will see, choose, or pay for distinctly.",
        :new_departure_composition_service, { departure_id: @departure.id }
      )
    elsif editable_packages.empty? && unowned_offers.any?
      findings << finding(
        "Itinerary and Package", :no_package, :incomplete,
        "Create a main package for components travelers buy together.",
        :new_departure_composition_service, { departure_id: @departure.id }
      )
    end

    editable_packages.each do |package|
      version = package.editable_draft_version
      next if version.inclusions.size >= 2

      if version.inclusions.empty?
        findings << finding(
          "Itinerary and Package", :empty_package, :incomplete,
          "Add a component to #{package.name}.",
          :new_departure_composition_service, { departure_id: @departure.id, package_id: package.id },
          package_id: package.id
        )
      end
    end
    findings
  end

  def supplier_findings
    findings = []
    each_editable_offer_version do |offer, version, definition|
      next unless definition&.undecided?

      findings << finding(
        "Supplier support", :undecided_fulfillment, :incomplete,
        "#{definition.client_title} is still an outline and makes no Supplier or capacity claim.",
        :fulfillment_departure_builder_component,
        { departure_id: @departure.id, id: offer.id, return_to: "services" },
        service_offer_id: offer.id,
        package_id: version.owning_package_version&.package_id
      )
    end
    findings
  end

  def pricing_findings
    findings = []
    editable_packages.each do |package|
      version = package.editable_draft_version
      next if version.nil?
      if version.price_definition.nil?
        findings << finding(
          "Pricing and Client terms", :package_price_missing, :incomplete,
          "Set a Package price for #{package.name}.",
          :departure_package, { departure_id: @departure.id, id: package.id },
          package_id: package.id
        )
      end
      version.inclusions.includes(service_offer_version: :price_definition).each do |inclusion|
        offer_version = inclusion.service_offer_version
        next if offer_version.price_definition.present?
        next if version.price_definition&.respond_to?(:bundled?) && false

        findings << finding(
          "Pricing and Client terms", :component_price_pending, :waiting,
          "Component price still open for #{offer_version.definition&.client_title || inclusion.service_offer.name}.",
          :departure_service_offer, { departure_id: @departure.id, id: inclusion.service_offer_id },
          service_offer_id: inclusion.service_offer_id,
          package_id: package.id
        )
      end
    end
    findings
  end

  def publish_findings
    findings = []
    return findings if editable_packages.empty? && unowned_offers.empty?

    unless @departure.active?
      findings << finding(
        "Ready to publish", :departure_not_active, :blocked,
        "Activate the Departure before publishing Client offers.",
        :departure_activation, { departure_id: @departure.id }
      )
    end

    each_editable_offer_version do |offer, version, definition|
      next if version.owning_package_version_id.present?
      readiness = EvaluateServiceOfferPublicationReadiness.new(agency: @agency, version: version).call
      next if readiness.ok

      findings << finding(
        "Ready to publish", :standalone_not_ready, :blocked,
        readiness.issues.first.message,
        :departure_service_offer, { departure_id: @departure.id, id: offer.id },
        service_offer_id: offer.id
      )
    end

    editable_packages.each do |package|
      version = package.editable_draft_version
      readiness = EvaluatePackagePublicationReadiness.new(agency: @agency, version: version).call
      next if readiness.ok

      findings << finding(
        "Ready to publish", :package_not_ready, :blocked,
        readiness.issues.first.message,
        :departure_package, { departure_id: @departure.id, id: package.id },
        package_id: package.id
      )
    end
    findings
  end

  def each_editable_offer_version
    @departure.service_offers.includes(versions: [ :definition, :owning_package_version ]).find_each do |offer|
      version = offer.editable_draft_version
      next if version.nil?

      yield offer, version, version.definition
    end
  end

  def finding(group, code, state, message, route_name, route_params, package_id: nil, service_offer_id: nil)
    Finding.new(
      group: group,
      code: code,
      state: state,
      message: message,
      route_name: route_name,
      route_params: route_params,
      package_id: package_id,
      service_offer_id: service_offer_id
    )
  end
end
