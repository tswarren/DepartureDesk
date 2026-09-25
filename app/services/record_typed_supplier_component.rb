# frozen_string_literal: true

class RecordTypedSupplierComponent < AgencyCommand
  include CostCommandSupport

  def initialize(agency:, actor:, arrangement:, category:, shapes:, attributes:, idempotency_key:)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @category = category
    @shapes = shapes
    @attributes = attributes.to_h.with_indifferent_access
    @idempotency_key = idempotency_key
  end

  def call
    ensure_arrangement_actor!
    shape = @shapes[@attributes[:shape].to_s]
    raise Error.new("Choose a supported Supplier cost.", code: :invalid) unless shape

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      arrangement = lock_arrangement_for!(@arrangement)
      version = arrangement.versions.find_by(status: "draft")
      raise Error.new("Open a successor draft before changing this cost.", code: :invalid_state) unless version

      item = arrangement.arrangement_items.find(@attributes[:arrangement_item_id])
      definition = version.arrangement_item_definitions.find_by!(arrangement_item_id: item.id)
      raise Error.new("That item is not part of this workspace.", code: :invalid) unless definition.category == @category
      raise Error.new("Open advanced Supplier planning for this cost.", code: :invalid) if unsupported_cost?(version, item)

      occurrence = item.service_occurrences.order(:created_at).first
      label = @attributes[:label].to_s.strip
      raise Error.new("Enter a cost label.", code: :invalid) if label.blank?

      existing = component_for_label(version, item, label)
      if existing
        UpdateSupplierCostComponent.new(
          agency: @agency, actor: @actor, component: existing,
          lock_version: existing.lock_version,
          definition_lock_version: existing.supplier_cost_definition.lock_version,
          attributes: component_attributes(shape, label)
        ).call
      else
        created = CreateSupplierCostSetup.new(
          agency: @agency, actor: @actor, arrangement: arrangement,
          version_lock_version: @attributes[:version_lock_version],
          idempotency_key: @idempotency_key,
          source_attributes: {
            charging_supplier_id: arrangement.contracting_supplier_id,
            label: label, arrangement_item_id: item.id, service_occurrence_id: occurrence&.id
          },
          definition_attributes: {
            stage: "contracted", mode: "calculated", currency: arrangement.departure.operating_currency,
            rounding_mode: "half_up"
          },
          component_attributes: component_attributes(shape, label)
        ).call
        record_minimum!(created.record.supplier_cost_definition) if @attributes[:minimum_quantity].present?
        created
      end
    end
  end

  private

  def component_attributes(shape, label)
    attrs = {
      label: label, economic_role: "supplier_charge", calculation_kind: shape[:calculation_kind],
      pass_through: false
    }
    if shape[:calculation_kind] == "percentage"
      attrs[:percentage] = @attributes[:percentage]
      attrs[:percentage_treatment] = @attributes[:percentage_treatment].presence || "additive"
    else
      attrs[:amount] = @attributes[:amount]
      attrs[:quantity_basis] = shape[:quantity_basis] if shape[:quantity_basis]
    end
    attrs
  end

  def record_minimum!(definition)
    CreateSupplierCostComponent.new(
      agency: @agency, actor: @actor, definition: definition.reload,
      definition_lock_version: definition.lock_version,
      idempotency_key: "#{@idempotency_key}-minimum",
      attributes: {
        label: "#{@attributes[:label].to_s.strip} minimum",
        economic_role: "supplier_charge",
        calculation_kind: "minimum_quantity_shortfall",
        pass_through: false,
        quantity_basis: "persons",
        minimum_quantity: @attributes[:minimum_quantity]
      }
    ).call
  end

  def component_for_label(version, item, label)
    SupplierCostComponent.joins(supplier_cost_definition: :supplier_cost_source)
      .where(supplier_cost_sources: { supplier_arrangement_version_id: version.id, arrangement_item_id: item.id })
      .find_by(label: label)
  end

  def unsupported_cost?(version, item)
    allowed = @shapes.values
    SupplierCostComponent.joins(supplier_cost_definition: :supplier_cost_source)
      .where(supplier_cost_sources: { supplier_arrangement_version_id: version.id, arrangement_item_id: item.id })
      .any? do |component|
        allowed.none? do |shape|
          component.calculation_kind == shape[:calculation_kind] &&
            (shape[:quantity_basis].nil? || component.quantity_basis == shape[:quantity_basis])
        end && component.calculation_kind != "minimum_quantity_shortfall"
      end
  end
end
