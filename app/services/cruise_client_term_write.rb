# frozen_string_literal: true

module CruiseClientTermWrite
  extend ActiveSupport::Concern

  include OfferCommandSupport
  include PriceCommandSupport

  private

  def load_context!(offer)
    version = offer.editable_draft_version
    raise AgencyCommand::Error.new("This Client service has no draft to edit.", code: :invalid_state) if version.nil?

    shape = DetectCruiseServiceConnectionShape.new(agency: @agency, offer: offer, version: version).call
    raise AgencyCommand::Error.new("Open advanced Client pricing for this service.", code: :invalid) unless shape.compatible?

    option = shape.choices.find { |choice| choice[:option].id == @attributes[:choice_option_id].to_s }&.fetch(:option)
    raise AgencyCommand::Error.new("That cabin category was not found.", code: :not_found) if option.nil?

    binding = shape.choices.find { |choice| choice[:option].id == option.id }.fetch(:binding)
    resource = @agency.supplier_resources.find(binding.supplier_resource_id)
    [ shape, option, binding, resource ]
  end

  def ensure_typed_graph!(version, option)
    definition = version.price_definition
    return if definition.nil?
    raise AgencyCommand::Error.new("Open advanced Client pricing for this service.", code: :invalid) unless definition.calculated?

    selected = definition.service_offer_price_components.select { |component| component.client_rate_category_key == option.client_rate_category_key }
    if selected.any? { |component| component.cruise_client_term_row_key.blank? || !CruiseClientTermRows.known?(component.cruise_client_term_row_key) }
      raise AgencyCommand::Error.new("Open advanced Client pricing for this service.", code: :invalid)
    end
    if definition.service_offer_price_components.any?(&:percentage?)
      raise AgencyCommand::Error.new("Open advanced Client pricing for this service.", code: :invalid)
    end
  end

  def normalized_cells
    Array(@attributes[:cells]).map { |cell| cell.to_h.with_indifferent_access }
  end

  def provenance_save?(version, option, cells)
    cells.any? { |cell| cell[:supplier_cost_component_id].present? && cell[:amount].present? } ||
      retained_provenance?(version, option, cells)
  end

  def retained_provenance?(version, option, cells)
    definition = version.price_definition
    return false if definition.nil?

    kept = cells.select { |cell| cell[:amount].present? && cell[:supplier_cost_component_id].blank? && !ActiveModel::Type::Boolean.new.cast(cell[:clear_provenance]) }
    kept.any? do |cell|
      definition.service_offer_price_components.any? do |component|
        component.client_rate_category_key == option.client_rate_category_key &&
          component.occupancy_position_key == cell[:band].to_s &&
          component.cruise_client_term_row_key == cell[:row_key].to_s &&
          component.copied_from_supplier_cost_component_id.present?
      end
    end
  end

  def idempotency_payload(offer, version, option, cells, arrangement_version)
    {
      departure_id: offer.departure_id,
      service_offer_id: offer.id,
      service_offer_version_id: version.id,
      choice_option_id: option.id,
      client_rate_category_key: option.client_rate_category_key,
      supplier_arrangement_version_id: arrangement_version&.id,
      cells: cells.map { |cell| digestable_cell(cell) }
    }
  end

  def digestable_cell(cell)
    {
      row_key: cell[:row_key].to_s,
      band: cell[:band].to_s,
      amount: cell[:amount].presence&.to_s,
      label: cell[:label].presence&.to_s,
      supplier_cost_component_id: cell[:supplier_cost_component_id].presence&.to_s,
      recopy: ActiveModel::Type::Boolean.new.cast(cell[:recopy]) == true,
      clear_provenance: ActiveModel::Type::Boolean.new.cast(cell[:clear_provenance]) == true
    }
  end

  def apply_cells!(departure, offer, version, option, binding, resource, cells)
    currency = require_operating_currency!(departure)
    definition = version.price_definition || ServiceOfferPriceDefinition.create!(
      agency: @agency, departure: departure, service_offer: offer, service_offer_version: version,
      currency: currency, mode: "calculated", rounding_mode: "half_up"
    )
    bands = CompileCruiseClientTermBandSet.new(
      agency: @agency, arrangement_version: binding.supplier_arrangement_version, resource: resource
    ).call
    raise AgencyCommand::Error.new(bands.unavailable_reasons[:base], code: :invalid) if bands.advanced?

    selected = definition.service_offer_price_components.select { |component| component.client_rate_category_key == option.client_rate_category_key }
    index = selected.index_by { |component| [ component.cruise_client_term_row_key, component.occupancy_position_key ] }
    seen = []

    cells.each do |cell|
      row_key = cell[:row_key].to_s
      band = cell[:band].to_s
      raise AgencyCommand::Error.new("That Client term row is not supported.", code: :invalid) unless CruiseClientTermRows.known?(row_key)
      raise AgencyCommand::Error.new("That traveler position is not supported.", code: :invalid) unless CruiseClientTermRows::BANDS.include?(band)
      next if cell[:amount].blank?

      unless bands.enabled.include?(band) || index[[ row_key, band ]]
        raise AgencyCommand::Error.new("That traveler position is not supported for this category.", code: :invalid)
      end
      unless CruiseClientTermRows.allowed_bands(row_key).include?(band)
        raise AgencyCommand::Error.new("That traveler position is not used for this row.", code: :invalid)
      end

      component = index[[ row_key, band ]]
      amount = money_minor_or_nil(cell[:amount], currency, "Amount", major_units: true)
      label = cell[:label].presence || component&.label || CruiseClientTermRows.label_for(row_key)
      role = CruiseClientTermRows.standard?(row_key) ? CruiseClientTermRows.role_for(row_key) : (component&.client_role || custom_role(row_key))
      if component
        component.update!(
          label: label, client_role: role, amount_minor_units: amount,
          **provenance_attributes(component, cell, binding)
        )
      else
        position = definition.service_offer_price_components.maximum(:position).to_i + 1
        component = definition.service_offer_price_components.create!(
          agency: @agency, departure: departure, service_offer: offer, service_offer_version: version,
          label: label, client_role: role, calculation_kind: "unit_rate", quantity_basis: "occupancy_positions",
          amount_minor_units: amount, occupancy_position_key: band, client_rate_category_key: option.client_rate_category_key,
          cruise_client_term_row_key: row_key, position: position,
          **provenance_attributes(nil, cell, binding)
        )
      end
      seen << component.id
    end

    selected.each do |component|
      next if seen.include?(component.id)
      next unless bands.enabled.include?(component.occupancy_position_key)

      component.destroy!
    end
    definition
  end

  def custom_role(row_key)
    row_key.include?("discount") ? "named_discount" : "named_surcharge"
  end

  def provenance_attributes(component, cell, binding)
    source_id = cell[:supplier_cost_component_id].presence
    recopy = ActiveModel::Type::Boolean.new.cast(cell[:recopy])
    clear = ActiveModel::Type::Boolean.new.cast(cell[:clear_provenance])
    if source_id.present? && (component.nil? || component.copied_from_supplier_cost_component_id.nil? || recopy)
      source = SupplierCostComponent.find(source_id)
      unless source.agency_id == @agency.id && source.departure_id == binding.departure_id &&
          source.supplier_arrangement_version_id == binding.supplier_arrangement_version_id
        raise AgencyCommand::Error.new("That Supplier term was not found.", code: :not_found)
      end
      unless %w[supplier_charge supplier_credit].include?(source.economic_role) && %w[fixed unit_rate].include?(source.calculation_kind)
        raise AgencyCommand::Error.new("That Supplier term cannot be copied.", code: :invalid)
      end
      snapshot = SupplierCostComponentCopyFingerprint.snapshot(
        mapped_client_role: CruiseClientTermRows.standard?(cell[:row_key]) ? CruiseClientTermRows.role_for(cell[:row_key]) : custom_role(cell[:row_key]),
        mapped_calculation_kind: "unit_rate",
        mapped_quantity_basis: "occupancy_positions",
        target_occupancy_position: cell[:band].to_s
      )
      return {
        copied_from_supplier_cost_component_id: source.id,
        copied_from_supplier_cost_component_fingerprint: SupplierCostComponentCopyFingerprint.hexdigest(source, snapshot),
        copied_from_supplier_cost_component_at: Time.current,
        copied_from_supplier_cost_component_mapping: snapshot
      }
    end
    return cleared_provenance if clear || source_id.blank? && component&.copied_from_supplier_cost_component_id.present? && cell.key?(:supplier_cost_component_id) && clear
    return cleared_provenance if clear

    if component&.copied_from_supplier_cost_component_id.present? && !clear
      return {
        copied_from_supplier_cost_component_id: component.copied_from_supplier_cost_component_id,
        copied_from_supplier_cost_component_fingerprint: component.copied_from_supplier_cost_component_fingerprint,
        copied_from_supplier_cost_component_at: component.copied_from_supplier_cost_component_at,
        copied_from_supplier_cost_component_mapping: component.copied_from_supplier_cost_component_mapping
      }
    end

    cleared_provenance
  end

  def cleared_provenance
    {
      copied_from_supplier_cost_component_id: nil,
      copied_from_supplier_cost_component_fingerprint: nil,
      copied_from_supplier_cost_component_at: nil,
      copied_from_supplier_cost_component_mapping: nil
    }
  end

  def remove_category!(version, option)
    definition = version.price_definition
    return if definition.nil?

    definition.service_offer_price_components.where(client_rate_category_key: option.client_rate_category_key).find_each(&:destroy!)
    definition.destroy! if definition.service_offer_price_components.reload.none? && definition.calculated?
  end

  def audit_terms!(offer, version, option, status, component_count, copied_count)
    audit!(
      agency: @agency, action: "service_offer.cruise_client_terms_saved", subject: offer, actor: @actor,
      details: {
        "service_offer_id" => offer.id,
        "service_offer_version_id" => version.id,
        "choice_option_id" => option.id,
        "component_count" => component_count,
        "copied_source_count" => copied_count,
        "status" => status
      }
    )
  end
end
