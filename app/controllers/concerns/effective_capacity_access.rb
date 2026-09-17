module EffectiveCapacityAccess
  extend ActiveSupport::Concern

  include SupplierArrangementAccess

  private

  def set_effective_capacity_context
    set_departure
    set_supplier_arrangement
    @supplier_arrangement_version = @supplier_arrangement.governing_version
    raise ActiveRecord::RecordNotFound unless @supplier_arrangement.active? &&
      @supplier_arrangement_version&.activated?

    @capacity_pool_definition = @supplier_arrangement_version.capacity_pool_definitions
      .find_by!(capacity_pool_id: params[:pool_id])
    @capacity_pool = @supplier_arrangement.capacity_pools.find(params[:pool_id])
    @arrangement_item_definition = @supplier_arrangement_version.arrangement_item_definitions.find_by!(
      arrangement_item_id: @capacity_pool.arrangement_item_id
    )
    @service_occurrence_definition = @supplier_arrangement_version.service_occurrence_definitions.find_by!(
      arrangement_item_id: @capacity_pool.arrangement_item_id,
      service_occurrence_id: @capacity_pool.service_occurrence_id
    )
    @supplier_resource_definition = @supplier_arrangement_version.supplier_resource_definitions.find_by!(
      arrangement_item_id: @capacity_pool.arrangement_item_id,
      supplier_resource_id: @capacity_pool.supplier_resource_id
    )
  end

  def load_effective_capacity
    RefreshDueCapacityProjection.new(
      agency: Current.agency,
      pool: @capacity_pool
    ).call
    @capacity_projection = @capacity_pool.reload.capacity_projection
    @capacity_events = @capacity_pool.capacity_events
      .includes(:actor, :reinstates_event, :corrects_event, :capacity_reconciliation)
      .order(effective_on: :desc, effective_sequence: :desc, recorded_at: :desc, id: :desc)
      .to_a
    @capacity_reconciliations = @capacity_pool.capacity_reconciliations
      .includes(:actor, resolutions: :capacity_event)
      .order(observed_at: :desc, recorded_at: :desc, id: :desc)
      .to_a
    @reinstatable_releases = @capacity_events.select(&:released?)
    @correctable_events = @capacity_events
    @open_reconciliations = @capacity_reconciliations.select(&:open_discrepancy?)
    @capacity_event ||= CapacityEvent.new
    @capacity_reconciliation ||= CapacityReconciliation.new
    @event_idempotency_key ||= SecureRandom.uuid
    @reconciliation_idempotency_key ||= SecureRandom.uuid
    @capacity_operable = (@departure.draft? || @departure.active?) &&
      @capacity_pool.numeric_inventory? && @capacity_projection.present?
    @capacity_event_types =
      if @capacity_pool.supplying_supplier.active?
        CapacityEvent::EVENT_TYPES - [ "established" ]
      else
        %w[released withdrawn corrected_down].tap do |types|
          types << "corrected_up" if Current.agency_user.permitted?(:override_supplier_planning_terms)
        end
      end
  end

  def render_effective_capacity(status: :unprocessable_entity)
    load_effective_capacity
    render "effective_capacity_pools/show", status: status
  end

  def add_effective_capacity_error(record, error)
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    record.errors.add(:base, error.message)
  end

  def capacity_evidence_params(source)
    source.permit(
      :evidence_kind,
      :evidence_on,
      :evidence_reference_note,
      :evidence_external_reference,
      :override,
      :override_reason,
      :resolution_note
    )
  end
end
