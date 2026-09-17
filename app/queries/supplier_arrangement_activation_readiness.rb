class SupplierArrangementActivationReadiness
  Blocker = Data.define(:track, :code, :path, :message)
  Result = Data.define(:version, :blockers, :cost_selections) do
    def ready? = blockers.empty?
  end

  def initialize(agency:, arrangement:, version:)
    @agency = agency
    @arrangement = arrangement
    @version = version
    @departure = arrangement.departure
    @blockers = []
    @cost_selections = []
  end

  def call
    verify_ownership
    structure_readiness
    capacity_readiness
    cost_readiness
    trigger_readiness
    Result.new(version: @version, blockers: @blockers.freeze, cost_selections: @cost_selections.freeze)
  rescue ActiveRecord::RecordNotFound
    block(:structure, :incomplete_graph, "arrangement", "The exact version graph is incomplete.")
    Result.new(version: @version, blockers: @blockers.freeze, cost_selections: [].freeze)
  end

  private

  def verify_ownership
    ids = [ @agency.id, @departure.agency_id, @arrangement.agency_id, @version.agency_id ]
    raise ActiveRecord::RecordNotFound unless ids.uniq.one?
    raise ActiveRecord::RecordNotFound unless
      @version.supplier_arrangement_id == @arrangement.id &&
      @version.departure_id == @departure.id
  end

  def structure_readiness
    definitions = @version.arrangement_item_definitions
      .includes(:default_service_provider, :arrangement_item).order(:position).to_a
    block(:structure, :items_missing, "items", "Add at least one Arrangement Item.") if definitions.empty?
    definitions.each do |item|
      occurrences = @version.service_occurrence_definitions
        .includes(:service_provider, :service_occurrence)
        .where(arrangement_item_id: item.arrangement_item_id).to_a
      resources = @version.supplier_resource_definitions
        .where(arrangement_item_id: item.arrangement_item_id).to_a
      block(:structure, :occurrences_missing, item_path(item), "Add at least one Service Occurrence.") if occurrences.empty?
      block(:structure, :resources_missing, item_path(item), "Add at least one Supplier Resource.") if resources.empty?
      occurrences.reject { |entry| entry.service_occurrence.cancelled? }.each do |occurrence|
        provider = occurrence.service_provider || item.default_service_provider || @arrangement.contracting_supplier
        unless provider&.active?
          block(:structure, :provider_inactive, "#{item_path(item)}.occurrences.#{occurrence.id}",
            "Every retained Occurrence must resolve one active Service Provider.")
        end
      end
    end
    block(:structure, :contracting_supplier_inactive, "contracting_supplier",
      "The contracting Supplier must be active.") unless @arrangement.contracting_supplier.active?
  end

  def capacity_readiness
    @version.arrangement_item_definitions.each do |item|
      if item.capacity_management.blank?
        block(:capacity, :management_undeclared, item_path(item),
          "Declare this Item managed or unmanaged.")
        next
      end
      next if item.unmanaged?

      occurrences = @version.service_occurrence_definitions
        .joins(:service_occurrence)
        .where(arrangement_item_id: item.arrangement_item_id, service_occurrences: { status: "planned" })
      resources = @version.supplier_resource_definitions.where(arrangement_item_id: item.arrangement_item_id)
      expected_pairs = occurrences.count * resources.count
      pairs = @version.capacity_pair_definitions.where(arrangement_item_id: item.arrangement_item_id)
      if expected_pairs.zero? || pairs.count != expected_pairs
        block(:capacity, :pairs_incomplete, item_path(item),
          "Classify every current Occurrence and Resource pair.")
      end
      pairs.includes(capacity_pool_definitions: :capacity_pool).each do |pair|
        if pair.pooled? && pair.capacity_pool_definitions.empty?
          block(:capacity, :pools_missing, "#{item_path(item)}.pairs.#{pair.id}",
            "Add at least one Capacity Pool for a pooled pair.")
        end
        pair.capacity_pool_definitions.each do |definition|
          pool = definition.capacity_pool
          provider = effective_provider(item, pool.service_occurrence_id)
          unless pool.supplying_supplier_id == provider&.id && provider&.active?
            block(:capacity, :supplying_supplier_mismatch, "#{item_path(item)}.pools.#{definition.id}",
              "The Pool supplying Supplier must be the active effective Provider.")
          end
          next if %w[on_request externally_managed].include?(pool.inventory_mode)
          unless definition.proposed_opening_quantity.to_i.positive? &&
              ((definition.evidence_kind.present? && definition.evidence_on.present? &&
                definition.evidence_reference_note.present?) || definition.override?)
            block(:capacity, :opening_authority_incomplete, "#{item_path(item)}.pools.#{definition.id}",
              "Numeric Pools require a positive opening quantity and complete authority.")
          end
        end
      end
    end
  end

  def cost_readiness
    sources = @version.supplier_cost_sources.includes(
      :charging_supplier, supplier_cost_definitions: :supplier_cost_components
    ).order(:position).to_a
    @version.arrangement_item_definitions.each do |item|
      unless sources.any? { |source| source.arrangement_item_id == item.arrangement_item_id }
        block(:cost, :item_coverage_missing, item_path(item),
          "Every retained Item requires an Item-level Supplier cost source.")
      end
    end
    sources.each do |source|
      selection = source.supplier_cost_definitions.find { |definition|
        definition.contracted? && definition.forecast_ready?
      } || source.supplier_cost_definitions.find { |definition|
        definition.estimate? && definition.forecast_ready?
      }
      unless selection
        block(:cost, :ready_definition_missing, "cost_sources.#{source.id}",
          "Each declared cost source needs one complete forecast-ready stage.")
        next
      end
      unless source.charging_supplier.active? && selection.currency == @departure.operating_currency
        block(:cost, :cost_authority_ineligible, "cost_sources.#{source.id}",
          "The selected cost authority must use an active Supplier and the Departure currency.")
      end
      @cost_selections << [ source, selection ]
    end
  end

  def trigger_readiness
    @version.supplier_commitment_trigger_definitions.includes(
      :committed_supplier, :supplier_cost_source, :supplier_cost_definition, :supplier_cost_component
    ).order(:position).each do |trigger|
      unless trigger.valid? && trigger.committed_supplier.active?
        block(:triggers, :trigger_incomplete, "commitment_triggers.#{trigger.id}",
          "Every declared commitment trigger must be complete and use an active committed Supplier.")
        next
      end
      if trigger.supplier_cost_definition &&
          (!trigger.supplier_cost_definition.contracted? ||
           !trigger.supplier_cost_definition.forecast_ready? ||
           !trigger.supplier_cost_component&.supplier_charge?)
        block(:triggers, :contracted_authority_invalid, "commitment_triggers.#{trigger.id}",
          "Monetary trigger authority must be a ready contracted Supplier charge.")
      end
    end
  end

  def effective_provider(item, occurrence_id)
    occurrence = @version.service_occurrence_definitions.find_by(service_occurrence_id: occurrence_id)
    occurrence&.service_provider || item.default_service_provider || @arrangement.contracting_supplier
  end

  def block(track, code, path, message)
    @blockers << Blocker.new(track:, code:, path:, message:)
  end

  def item_path(item)
    "items.#{item.arrangement_item_id}"
  end
end
