# frozen_string_literal: true

class RecordHotelDeposit < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, arrangement:, attributes:, idempotency_key:)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @attributes = attributes.to_h.with_indifferent_access
    @idempotency_key = idempotency_key
  end

  def call
    ensure_arrangement_actor!
    arrangement = @agency.supplier_arrangements.find(@arrangement.id)
    version = arrangement.versions.find_by(status: "draft")
    raise Error.new("Open a successor draft before changing this deposit.", code: :invalid_state) unless version

    item = arrangement.arrangement_items.find(@attributes[:arrangement_item_id])
    definition = version.arrangement_item_definitions.find_by!(arrangement_item_id: item.id)
    raise Error.new("That item is not part of this workspace.", code: :invalid) unless definition.category == "lodging"

    sources = version.supplier_cost_sources.where(arrangement_item_id: item.id).order(:position, :id)
    raise Error.new("Add a Supplier cost before the deposit percentage.", code: :invalid) if sources.empty?

    occurrence = version.service_occurrence_definitions.find_by(arrangement_item_id: item.id)
    CreateSupplierDepositRequirementDefinition.new(
      agency: @agency, actor: @actor, version: version,
      version_lock_version: @attributes[:version_lock_version],
      idempotency_key: @idempotency_key,
      attributes: {
        amount_shape: "percentage_of_cost_sources",
        percentage: @attributes[:percentage],
        rounding_scope: "aggregate",
        currency: arrangement.departure.operating_currency,
        description: @attributes[:description].presence || "Deposit on guaranteed rooms",
        rule_shape: "fixed_date",
        rule_parameters: { "date" => @attributes[:date].to_s },
        precision: "date_only",
        time_zone: @attributes[:time_zone].presence || occurrence&.time_zone || arrangement.departure.time_zone,
        coverage_links: [ { arrangement_item_id: item.id } ],
        cost_links: sources.map { |source| { supplier_cost_source_id: source.id } }
      }
    ).call
  end
end
