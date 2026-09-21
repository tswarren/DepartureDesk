# frozen_string_literal: true

class CreatePackagePriceDefinition < AgencyCommand
  include PackageCommandSupport
  include PriceCommandSupport

  def initialize(agency:, actor:, package:, attributes:, version_lock_version:, idempotency_key: nil)
    @agency = agency
    @actor = actor
    @package = package
    @attributes = attributes.to_h.with_indifferent_access
    @version_lock_version = version_lock_version
    @idempotency_key = idempotency_key || @attributes.delete(:idempotency_key)
  end

  def call
    ensure_offer_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_offer_agency!
      departure, package, version = lock_departure_package_draft!(@package)
      ensure_package_draft_editable!(departure, package, version)
      ensure_departure_accepts_price_expansion!(departure)
      currency = require_operating_currency!(departure)
      mode = @attributes[:mode].to_s.presence || "bundled"
      unless PackagePriceDefinition::MODES.include?(mode)
        raise Error.new("Choose bundled or sum of service prices.", code: :invalid)
      end
      supplement = mode == "bundled" ? @attributes[:single_occupancy_supplement_rate] : nil
      components = Array(@attributes[:components])
      if mode == "bundled" && components.blank?
        raise Error.new("Enter an unscoped per-person package price.", code: :invalid)
      end

      idempotent_create!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload: { package_id: package.id, package_version_id: version.id, mode: mode, components: components },
        result_class: PackagePriceDefinition
      ) do
        ensure_current_lock_version!(version, @version_lock_version)
        lock_service_offers_in_uuid_order!(version.inclusions.map(&:service_offer_id))
        raise Error.new("This package already has a price.", code: :invalid_state) if version.price_definition

        definition = PackagePriceDefinition.create!(
          agency: @agency, departure: departure, package: package, package_version: version,
          currency: currency, mode: mode, rounding_mode: "half_up",
          single_occupancy_supplement_rate: supplement
        )
        create_components!(definition, version, package, departure, components, mode)
        bump_version!(version)
        audit!(
          agency: @agency, action: "package.price_created", subject: package, actor: @actor,
          details: package_audit_details(package, version, "mode" => mode)
        )
        definition
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def create_components!(definition, version, package, departure, components, mode)
    created = []
    components.each_with_index do |raw, index|
      attrs = normalize_price_component_attributes(raw, currency: definition.currency, position: index + 1)
      if mode == "bundled" && attrs[:client_role] == "base_price"
        unless attrs[:calculation_kind] == "unit_rate" && attrs[:quantity_basis] == "persons"
          raise Error.new("Bundled package base price must be an unscoped per-person rate.", code: :invalid)
        end
        if raw.to_h.with_indifferent_access[:occupancy_position_key].present? ||
            raw.to_h.with_indifferent_access[:client_rate_category_key].present?
          raise Error.new("Package bundled price cannot use occupancy or rate-category selectors.", code: :invalid)
        end
      end
      if mode == "service_sum"
        unless %w[named_discount named_surcharge].include?(attrs[:client_role]) && attrs[:calculation_kind] == "fixed"
          raise Error.new("Service-sum package prices accept only fixed named discounts and surcharges.", code: :invalid)
        end
      end
      created << definition.package_price_components.create!(
        agency: @agency, departure: departure, package: package, package_version: version,
        **attrs.except(:bases, :client_rate_category_key, :occupancy_position_key)
      )
    end
    created.each_with_index do |component, index|
      bases = Array(components[index].to_h.with_indifferent_access[:bases])
      next if bases.blank?
      raise Error.new("Only percentage components accept bases.", code: :invalid) unless component.percentage?
      raise Error.new("Service-sum package prices cannot use percentage adjustments.", code: :invalid) if mode == "service_sum"

      bases.each_with_index do |base_raw, base_index|
        identifier = base_raw.to_h.with_indifferent_access[:base_component_id].presence ||
          base_raw.to_h.with_indifferent_access[:base_position]
        base = created.find { |row| row.id.to_s == identifier.to_s } || created.find { |row| row.position == identifier.to_i }
        raise Error.new("A percentage base was not found.", code: :invalid) if base.nil?

        component.package_price_component_bases.create!(
          agency: @agency, departure: departure, package: package, package_version: version,
          package_price_definition: definition, base_component: base,
          direction: (base_raw.to_h.with_indifferent_access[:direction].presence || "add"),
          position: base_index + 1
        )
      end
    end
    created
  end
end
