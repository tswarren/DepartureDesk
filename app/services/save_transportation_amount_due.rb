# frozen_string_literal: true

class SaveTransportationAmountDue < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, arrangement:, due_on:, idempotency_key:)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @due_on = due_on
    @idempotency_key = idempotency_key
  end

  def call
    ensure_arrangement_actor!
    date = Date.iso8601(@due_on.to_s)
    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      departure = lock_departure_for!(@arrangement.departure_id)
      arrangement = lock_arrangement_for!(@arrangement)
      version = arrangement.versions.lock.find_by!(status: "draft")
      components = transportation_components(version)
      if components.empty? || components.any? { |component| component.quantity_capacity_pool_id.blank? }
        raise Error.new("Charter amount due needs a capacity-backed rate on each segment.", code: :invalid)
      end

      definition = version.supplier_amount_due_definitions.first
      if definition
        definition.update!(
          currency: departure.operating_currency,
          time_zone: departure.time_zone,
          rule_parameters: { "date" => date.iso8601 }
        )
        replace_contributors!(definition, components)
      else
        definition = version.supplier_amount_due_definitions.create!(
          agency: @agency,
          departure:,
          supplier_arrangement: arrangement,
          currency: departure.operating_currency,
          rule_shape: "fixed_date",
          precision: "date_only",
          time_zone: departure.time_zone,
          rule_parameters: { "date" => date.iso8601 },
          position: 1
        )
        replace_contributors!(definition, components)
      end
      audit!(
        agency: @agency,
        action: "supplier_arrangement.amount_due_definition_saved",
        subject: arrangement,
        actor: @actor,
        details: {
          "supplier_arrangement_id" => arrangement.id,
          "supplier_arrangement_version_id" => version.id,
          "supplier_amount_due_definition_id" => definition.id,
          "due_on" => date.iso8601
        }
      )
      definition
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  rescue Date::Error
    raise Error.new("Enter the charter amount due date.", code: :invalid)
  end

  private

  def transportation_components(version)
    item_ids = version.arrangement_item_definitions.where(category: "ground_transportation").order(:position, :id).pluck(:arrangement_item_id)
    item_ids.filter_map do |item_id|
      version.supplier_cost_components.joins(supplier_cost_definition: :supplier_cost_source)
        .where(supplier_cost_sources: { arrangement_item_id: item_id })
        .where(calculation_kind: "unit_rate", quantity_basis: "resource_units", economic_role: "supplier_charge")
        .order(:position).first
    end
  end

  def replace_contributors!(definition, components)
    definition.supplier_amount_due_contributors.order(:position).destroy_all
    components.each_with_index do |component, index|
      definition.supplier_amount_due_contributors.create!(
        agency: definition.agency,
        departure: definition.departure,
        supplier_arrangement: definition.supplier_arrangement,
        supplier_arrangement_version: definition.supplier_arrangement_version,
        supplier_cost_component: component,
        position: index + 1
      )
    end
  end
end
