# frozen_string_literal: true

class HotelSupplierRatesController < ApplicationController
  include HotelArrangementAccess

  RateChange = Data.define(:context, :kind, :minor, :component, :remove)
  COMPONENT_LABELS = {
    base: "Room night base",
    third: "Third occupant",
    fourth: "Fourth occupant"
  }.freeze

  before_action :require_departure_view!, only: :show
  before_action :require_departure_management!, except: :show
  before_action :set_departure
  before_action :ensure_composable_departure!
  before_action :set_supplier_arrangement
  before_action :set_hotel_version
  before_action :set_hotel_item
  before_action :assign_hotel_composition_context
  before_action :prepare_rates

  def show
  end

  def update
    @submitted_noncommissionable = ActiveModel::Type::Boolean.new.cast(params[:noncommissionable]) || false
    return render_blocked if @rate_shape.blocked? || !hotel_editable?

    unless locks_current?
      @form_error = "Supplier rates changed while you were editing them."
      render :show, status: :unprocessable_entity
      return
    end

    changes = rate_changes
    if @form_error
      render :show, status: :unprocessable_entity
      return
    end
    unless @submitted_noncommissionable
      @commission_invalid = true
      @form_error = "Confirm Net and noncommissionable before saving Supplier rates."
      render :show, status: :unprocessable_entity
      return
    end

    ActiveRecord::Base.transaction do
      apply_rates!(changes)
    end
    redirect_to rates_path, notice: "Supplier rates saved."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @form_error = error.message
    flash.now[:alert] = error.message
    prepare_rates
    render :show, status: :unprocessable_entity
  end

  private

  def prepare_rates
    @rate_shape = DetectHotelRateShape.new(
      agency: Current.agency,
      arrangement: @supplier_arrangement,
      version: @supplier_arrangement_version,
      item: @arrangement_item,
      departure: @departure
    ).call
    @shape = @rate_shape.inventory
    @illustration = IllustrateHotelSupplierRates.new(
      agency: Current.agency,
      departure: @departure,
      arrangement: @supplier_arrangement,
      version: @supplier_arrangement_version,
      shape: @rate_shape
    ).call
    @editable = hotel_editable? && !@rate_shape.blocked?
    @idempotency_key = params[:idempotency_key].presence || @idempotency_key || SecureRandom.uuid
    @submitted_rate_values ||= {}
    @invalid_rate_fields ||= []
  end

  def render_blocked
    @editable = false
    @form_error = @rate_shape.reasons.first || @shape.reasons.first || "This Hotel graph cannot be edited here."
    render :show, status: :unprocessable_entity
  end

  def rates_path
    default_path = item_rates_departure_arrangement_hotel_path(@departure, @supplier_arrangement, @arrangement_item)
    path_after_hotel_edit(default_path)
  end

  def locks_current?
    locks = nested_hash(:definition_lock)
    component_locks = nested_hash(:component_lock)
    @rate_shape.contexts.each do |context|
      definition = context.definition
      next unless definition

      submitted_definition = locks[definition.id.to_s]
      return false if submitted_definition.blank? || submitted_definition.to_i != definition.lock_version

      %i[base third fourth].each do |kind|
        component = context.public_send(kind)
        next unless component

        submitted_component = component_locks[component.id.to_s]
        return false if submitted_component.blank? || submitted_component.to_i != component.lock_version
      end
    end
    true
  end

  def rate_changes
    @submitted_rate_values = Hash.new { |resources, resource_id| resources[resource_id] = Hash.new { |dates, date| dates[date] = {} } }
    @invalid_rate_fields = []
    base = nested_hash(:base)
    supplement = nested_hash(:supplement)
    contexts = @rate_shape.supported_contexts
    if contexts.empty?
      return [] if base.empty? && supplement.empty?

      return fail_rates("Record room inventory before Supplier rates.")
    end
    return if rejected_rate_keys?(base, supplement, contexts)
    return if compact_rates_disagree?(base, supplement, contexts)

    changes = []
    error = nil
    contexts.each do |context|
      {
        base: raw_base(base, context),
        third: raw_supplement(supplement, "3", context),
        fourth: raw_supplement(supplement, "4", context)
      }.each do |kind, raw|
        @submitted_rate_values[context.resource_id.to_s][context.date.iso8601][kind.to_s] = raw.to_s
        component = context.public_send(kind)
        minor = minor_units_for(raw)
        if minor == :blank
          if component && kind == :base
            @invalid_rate_fields << rate_field_key(context, kind)
            error ||= "Enter a Supplier rate."
          elsif component
            changes << RateChange.new(context: context, kind: kind, minor: nil, component: component, remove: true)
          end
          next
        end
        if minor == :invalid
          @invalid_rate_fields << rate_field_key(context, kind)
          error ||= "Amount is invalid."
          next
        end
        next if component&.amount_minor_units == minor

        changes << RateChange.new(context: context, kind: kind, minor: minor, component: component, remove: false)
      end
    end
    return fail_rates(error) if error

    changes
  end

  def rejected_rate_keys?(base, supplement, contexts)
    known_ids = contexts.map { |context| context.resource_id.to_s }.uniq
    if (base.keys.map(&:to_s) - known_ids).any?
      fail_rates("This Supplier rate cannot be edited here.")
      return true
    end

    %w[3 4].each do |position|
      node = supplement[position]
      next unless node.is_a?(Hash)
      next if (node.keys.map(&:to_s) - known_ids).empty?

      fail_rates("This Supplier rate cannot be edited here.")
      return true
    end

    contexts.group_by { |context| context.resource_id.to_s }.each do |resource_id, rows|
      known_dates = rows.map { |context| context.date.iso8601 }
      [ base[resource_id], hash_value(supplement["3"], resource_id), hash_value(supplement["4"], resource_id) ].each do |node|
        next unless node.is_a?(Hash)
        next if (node.keys.map(&:to_s) - known_dates).empty?

        fail_rates("This Supplier rate cannot be edited here.")
        return true
      end
    end
    false
  end

  def compact_rates_disagree?(base, supplement, contexts)
    contexts.group_by { |context| context.resource_id.to_s }.each do |resource_id, rows|
      next unless base[resource_id].is_a?(String)
      next unless rows.map { |context| context.base&.amount_minor_units }.uniq.size > 1

      fail_rates("These nights already have different rates.")
      return true
    end
    { "3" => :third, "4" => :fourth }.each do |position, kind|
      node = supplement[position]
      if node.is_a?(String) && contexts.map { |context| context.public_send(kind)&.amount_minor_units }.uniq.size > 1
        fail_rates("These nights already have different rates.")
        return true
      end
      next unless node.is_a?(Hash)

      node.each do |resource_id, value|
        next unless value.is_a?(String)

        rows = contexts.select { |context| context.resource_id.to_s == resource_id.to_s }
        next unless rows.map { |context| context.public_send(kind)&.amount_minor_units }.uniq.size > 1

        fail_rates("These nights already have different rates.")
        return true
      end
    end
    false
  end

  def raw_base(base, context)
    node = base[context.resource_id.to_s]
    return if node.nil?
    return node if node.is_a?(String)

    node[context.date.iso8601]
  end

  def raw_supplement(supplement, position, context)
    node = supplement[position]
    return if node.nil?
    return node if node.is_a?(String)

    resource_node = node[context.resource_id.to_s]
    return if resource_node.nil?
    return resource_node if resource_node.is_a?(String)

    resource_node[context.date.iso8601]
  end

  def minor_units_for(raw)
    text = raw.to_s.strip
    return :blank if text.empty?

    amount = BigDecimal(text)
    return :invalid if amount.negative?

    Money.from_amount(amount, @departure.operating_currency).fractional
  rescue ArgumentError, Money::Currency::UnknownCurrency
    :invalid
  end

  def fail_rates(message)
    @form_error = message
    nil
  end

  def rate_field_key(context, kind)
    "#{context.resource_id}--#{context.date.iso8601}--#{kind}"
  end

  def hash_value(node, key)
    return unless node.is_a?(Hash)

    node[key]
  end

  def nested_hash(key)
    value = params[key]
    return {} unless value.respond_to?(:to_unsafe_h)

    value.to_unsafe_h
  end

  def apply_rates!(changes)
    @rate_shape.supported_contexts.each do |context|
      group = changes.select { |change| change.context.equal?(context) }
      existing = context.definition
      needs_commission = @submitted_noncommissionable && existing && !existing.noncommissionable?
      next if group.empty? && !needs_commission

      if group.any?
        source = ensure_source!(context)
        definition = ensure_definition!(context, source)
        group.sort_by { |change| change.remove ? 0 : (change.component ? 1 : 2) }.each do |change|
          write_component!(definition, context, change)
        end
        set_commission!(definition) if @submitted_noncommissionable
      else
        set_commission!(existing)
      end
    end
  end

  def ensure_source!(context)
    return context.source if context.source

    version = reload_authorized_version!
    CreateSupplierCostSource.new(
      **hotel_command_context,
      arrangement: @supplier_arrangement,
      version_lock_version: version.lock_version,
      idempotency_key: rate_idempotency_key("source:#{context.occurrence_id}:#{context.resource_id}"),
      attributes: {
        arrangement_item_id: @arrangement_item.id,
        service_occurrence_id: context.occurrence_id,
        supplier_resource_id: context.resource_id,
        charging_supplier_id: @supplier_arrangement.contracting_supplier_id,
        label: "#{context.cell.night_definition.name} #{context.resource_definition.name}".truncate(SupplierCostSource::LABEL_LIMIT)
      }
    ).call.record
  end

  def ensure_definition!(context, source)
    return context.definition if context.definition

    source.reload
    found = source.supplier_cost_definitions.find { |definition| definition.contracted? && definition.calculated? }
    return found if found

    CreateSupplierCostDefinition.new(
      **hotel_command_context,
      source: source,
      source_lock_version: source.lock_version,
      idempotency_key: rate_idempotency_key("definition:#{context.occurrence_id}:#{context.resource_id}"),
      attributes: {
        stage: "contracted",
        mode: "calculated",
        currency: @departure.operating_currency,
        rounding_mode: "half_up"
      }
    ).call.record
  end

  def write_component!(definition, context, change)
    if change.remove
      definition.reload
      RemoveSupplierCostComponent.new(
        **hotel_command_context,
        component: change.component,
        definition_lock_version: definition.lock_version
      ).call
      return
    end

    if change.component
      return if change.component.amount_minor_units == change.minor

      UpdateSupplierCostComponent.new(
        **hotel_command_context,
        component: change.component,
        lock_version: change.component.lock_version,
        attributes: { amount_minor_units: change.minor }
      ).call
      return
    end

    definition.reload
    attributes = {
      label: COMPONENT_LABELS.fetch(change.kind),
      economic_role: "supplier_charge",
      calculation_kind: "unit_rate",
      amount_minor_units: change.minor,
      quantity_basis: change.kind == :base ? "resource_nights" : "occupancy_position_nights",
      pass_through: false
    }
    if change.kind != :base
      position = change.kind == :third ? 3 : 4
      attributes[:occupancy_position_from] = position
      attributes[:occupancy_position_to] = position
    end
    CreateSupplierCostComponent.new(
      **hotel_command_context,
      definition: definition,
      definition_lock_version: definition.lock_version,
      idempotency_key: rate_idempotency_key("component:#{context.occurrence_id}:#{context.resource_id}:#{change.kind}"),
      attributes: attributes
    ).call
  end

  def rate_idempotency_key(suffix)
    "#{@idempotency_key}:#{Digest::SHA256.hexdigest(suffix)[0, 40]}"
  end

  def set_commission!(definition)
    definition.reload
    return if definition.noncommissionable?

    SetSupplierCostCommissionTreatment.new(
      **hotel_command_context,
      definition: definition,
      commission_treatment: "noncommissionable",
      lock_version: definition.lock_version
    ).call
  end
end
