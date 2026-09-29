# frozen_string_literal: true

# Cruise summary orchestration. Removal still goes through the existing
# resource, pool, pair, and cost commands. A category stays when those
# commands cannot finish.
class RemoveCruiseCabinCategory < AgencyCommand
  include ArrangementCommandSupport

  def self.possible?(version:, resource:)
    return false unless version&.draft? && resource

    definition = version.supplier_resource_definitions.find_by(supplier_resource: resource)
    return false unless definition
    return false if shared_with_another_version?(version, resource, definition)
    return false if draft_references?(version, resource)
    return false if ArrangementItemSetupResult.where(supplier_resource: resource).exists?

    version.capacity_pool_definitions.where(supplier_resource: resource).all? do |pool_definition|
      pool_can_be_removed?(pool_definition)
    end
  end

  def self.shared_with_another_version?(version, resource, definition)
    SupplierResourceDefinition.where(supplier_resource_id: resource.id)
      .where.not(supplier_arrangement_version_id: version.id).exists? ||
      SupplierResourceDefinition.where(copied_from_id: definition.id).exists?
  end

  def self.draft_references?(version, resource)
    version.supplier_deposit_requirement_definition_coverage_links.where(supplier_resource: resource).exists? ||
      version.supplier_deadline_definition_coverage_links.where(supplier_resource: resource).exists? ||
      version.supplier_commitment_trigger_definitions.where(supplier_resource: resource).exists? ||
      version.supplier_commitments.where(supplier_resource: resource).exists? ||
      version.supplier_reservation_scopes.where(supplier_resource: resource).exists? ||
      version.service_offer_source_bindings.where(supplier_resource: resource).exists?
  end

  def self.pool_can_be_removed?(pool_definition)
    pool = pool_definition.capacity_pool
    return false if pool.definitions.where.not(id: pool_definition.id).exists?
    return false if pool.capacity_events.exists?
    return false if pool.capacity_projection.present?
    return false if pool.capacity_reconciliations.exists?
    return false if SupplierArrangementActivationCapacityEntry.where(capacity_pool_definition: pool_definition).exists?
    return false if SupplierArrangementCruiseCapacityDepositRequirement.where(capacity_pool: pool).exists?

    true
  end

  private_class_method :shared_with_another_version?, :draft_references?, :pool_can_be_removed?

  def initialize(agency:, actor:, arrangement:, resource:, version_lock_version:)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @resource = resource
    @version_lock_version = version_lock_version
  end

  def call
    ensure_arrangement_actor!
    arrangement = nil

    ActiveRecord::Base.transaction do
      arrangement = @agency.supplier_arrangements.find(@arrangement.id)
      version = arrangement.versions.find_by!(status: "draft")
      ensure_current_lock_version!(version, @version_lock_version)
      resource = arrangement.supplier_resources.find(@resource.id)
      unless self.class.possible?(version: version, resource: resource)
        raise Error.new("That cabin category cannot be removed from this draft.", code: :dependency_exists)
      end

      remove_rates!(version, resource)
      version.reload
      remove_capacity!(version, resource)
      version.reload
      RemoveSupplierResource.new(
        agency: @agency,
        actor: @actor,
        resource: resource,
        version_lock_version: version.lock_version
      ).call
    end

    Result.new(status: :updated, record: arrangement.reload)
  rescue ActiveRecord::RecordNotFound
    raise Error.new("That cabin category was not found.", code: :not_found)
  rescue ActiveRecord::DeleteRestrictionError, ActiveRecord::InvalidForeignKey
    raise Error.new("That cabin category cannot be removed from this draft.", code: :dependency_exists)
  end

  private

  def remove_rates!(version, resource)
    version.supplier_cost_usage_assumptions.where(supplier_resource: resource).order(:id).each do |assumption|
      assumption.supplier_cost_occupancy_profiles.order(:position, :id).each do |profile|
        RemoveSupplierCostOccupancyProfile.new(
          agency: @agency,
          actor: @actor,
          profile: profile,
          assumption_lock_version: assumption.reload.lock_version
        ).call
      end
      RemoveSupplierCostUsageAssumption.new(
        agency: @agency,
        actor: @actor,
        assumption: assumption,
        lock_version: assumption.reload.lock_version
      ).call
    end

    version.reload
    version.supplier_cost_sources.where(supplier_resource: resource).order(:id).each do |source|
      RemoveSupplierCostSource.new(
        agency: @agency,
        actor: @actor,
        source: source,
        version_lock_version: version.lock_version
      ).call
      version.reload
    end
  end

  def remove_capacity!(version, resource)
    version.capacity_pool_definitions.where(supplier_resource: resource).order(:id).each do |definition|
      RemoveCapacityPool.new(
        agency: @agency,
        actor: @actor,
        definition: definition,
        version_lock_version: version.lock_version,
        lock_version: definition.lock_version
      ).call
      version.reload
    end

    pair = version.capacity_pair_definitions.find_by(supplier_resource: resource)
    return unless pair

    RemoveCapacityPairClassification.new(
      agency: @agency,
      actor: @actor,
      pair: pair,
      version_lock_version: version.lock_version,
      lock_version: pair.lock_version
    ).call
  end
end
