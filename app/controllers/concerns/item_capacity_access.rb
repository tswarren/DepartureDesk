module ItemCapacityAccess
  extend ActiveSupport::Concern

  include SupplierArrangementAccess

  private

  def set_capacity_context
    set_departure
    set_supplier_arrangement
    set_initial_version
    set_arrangement_item
    set_item_definition
  end

  def load_capacity_graph
    @occurrence_definitions = @supplier_arrangement_version.service_occurrence_definitions
      .includes(:service_occurrence, :service_provider)
      .where(arrangement_item: @arrangement_item)
      .order(Arel.sql("starts_on ASC, CASE WHEN starts_at_local IS NULL THEN 0 ELSE 1 END ASC, starts_at_local ASC NULLS FIRST, lower(name) ASC, id ASC"))
      .to_a
    @active_occurrence_definitions = @occurrence_definitions.reject { |definition| definition.service_occurrence.cancelled? }
    @retained_cancelled_occurrence_definitions = @occurrence_definitions.select { |definition| definition.service_occurrence.cancelled? }
    @resource_definitions = @supplier_arrangement_version.supplier_resource_definitions
      .includes(:supplier_resource)
      .where(arrangement_item: @arrangement_item)
      .order(:position, :id)
      .to_a
    @capacity_pairs_by_members = @supplier_arrangement_version.capacity_pair_definitions
      .includes(capacity_pool_definitions: { capacity_pool: :supplying_supplier })
      .where(arrangement_item: @arrangement_item)
      .index_by { |pair| [ pair.service_occurrence_id, pair.supplier_resource_id ] }
    @capacity_pool_definitions_by_pair_id = @supplier_arrangement_version.capacity_pool_definitions
      .includes(capacity_pool: :supplying_supplier)
      .where(arrangement_item: @arrangement_item)
      .order(:position, :id)
      .group_by(&:capacity_pair_definition_id)
    @bulk_idempotency_key ||= SecureRandom.uuid
    @idempotency_key_by_pair_id ||= {}
    @capacity_pairs_by_members.each_value do |pair|
      @idempotency_key_by_pair_id[pair.id] ||= SecureRandom.uuid
    end
  end

  def set_capacity_pair
    @capacity_pair = @supplier_arrangement_version.capacity_pair_definitions.find_by!(
      id: params[:pair_id],
      arrangement_item: @arrangement_item
    )
  end

  def set_capacity_pool_definition
    @capacity_pool_definition = @supplier_arrangement_version.capacity_pool_definitions.find_by!(
      capacity_pair_definition: @capacity_pair,
      capacity_pool_id: params[:id]
    )
  end

  def capacity_pool_params
    params.fetch(:capacity_pool, ActionController::Parameters.new).permit(
      :inventory_mode,
      :measurement_basis,
      :label,
      :notes,
      :unit_label,
      :proposed_opening_quantity,
      :evidence_kind,
      :evidence_on,
      :evidence_reference_note,
      :evidence_external_reference,
      :override,
      :override_reason,
      :lock_version
    )
  end

  def render_capacity_show(status: :unprocessable_entity)
    load_capacity_graph
    render "item_capacities/show", status: status
  end

  def add_capacity_error(record, error)
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    if error.code == :invalid
      record.errors.add(capacity_error_attribute(error.message), error.message)
    else
      flash.now[:alert] = error.message
    end
  end

  def capacity_error_attribute(message)
    case message
    when /label/i then :label
    when /unit label/i then :unit_label
    when /quantity/i then :proposed_opening_quantity
    when /evidence kind/i then :evidence_kind
    when /evidence date/i then :evidence_on
    when /evidence note/i then :evidence_reference_note
    when /external reference/i then :evidence_external_reference
    when /override reason|reason/i then :override_reason
    else :base
    end
  end
end
