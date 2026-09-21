# frozen_string_literal: true

class CreatePackageSuccessorDraft < AgencyCommand
  include PackageCommandSupport

  def initialize(agency:, actor:, package:, version_lock_version:, idempotency_key:)
    @agency = agency
    @actor = actor
    @package = package
    @version_lock_version = version_lock_version
    @idempotency_key = idempotency_key
  end

  def call
    ensure_offer_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_offer_agency!
      package = lock_package_for!(@package)
      departure = lock_departure_for!(package.departure_id)
      predecessor = package.current_published_version
      raise Error.new("Publish a version before creating a successor.", code: :invalid_state) if predecessor.nil?
      predecessor = package.versions.lock.find(predecessor.id)
      ensure_current_lock_version!(predecessor, @version_lock_version)
      raise Error.new("A successor draft already exists.", code: :conflict) if package.editable_draft_version

      idempotent_create!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload: { package_id: package.id, predecessor_version_id: predecessor.id },
        result_class: PackageVersion
      ) do
        successor = package.versions.create!(
          agency: @agency, departure: departure,
          version_number: package.versions.maximum(:version_number).to_i + 1,
          status: "draft",
          copied_from_version: predecessor,
          sales_starts_on: predecessor.sales_starts_on,
          sales_ends_on: predecessor.sales_ends_on,
          sales_cap_quantity: predecessor.sales_cap_quantity,
          sales_cap_basis: predecessor.sales_cap_basis
        )
        copy_package_graph!(package, departure, predecessor, successor)
        audit!(
          agency: @agency, action: "package.successor_created", subject: package, actor: @actor,
          details: package_audit_details(package, successor, "predecessor_version_id" => predecessor.id)
        )
        successor
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  rescue ActiveRecord::RecordNotUnique
    raise Error.new("A successor draft already exists.", code: :conflict)
  end

  private

  def copy_package_graph!(package, departure, from, to)
    from.inclusions.order(:position).each do |inclusion|
      sov = inclusion.service_offer_version
      if sov.owning_package_version_id == from.id
        offer = sov.service_offer
        new_sov = offer.versions.create!(
          agency: @agency, departure: departure,
          version_number: offer.versions.maximum(:version_number).to_i + 1,
          status: "draft",
          copied_from_version: sov,
          owning_package_version: to,
          sales_cap_quantity: sov.sales_cap_quantity,
          sales_cap_basis: sov.sales_cap_basis
        )
        OfferVersionGraphCopy.copy_service_offer_version!(
          agency: @agency, departure: departure, offer: offer, from: sov, to: new_sov
        )
        pin_sov = new_sov
      else
        pin_sov = sov
      end
      to.inclusions.create!(
        agency: @agency, departure: departure, package: package,
        service_offer: pin_sov.service_offer, service_offer_version: pin_sov,
        placement: inclusion.placement, origin: inclusion.origin, position: inclusion.position
      )
    end

    if from.price_definition
      price = to.create_price_definition!(
        agency: @agency, departure: departure, package: package,
        currency: from.price_definition.currency, mode: from.price_definition.mode,
        rounding_mode: from.price_definition.rounding_mode,
        single_occupancy_supplement_rate: from.price_definition.single_occupancy_supplement_rate
      )
      from.price_definition.package_price_components.order(:position).each do |component|
        price.package_price_components.create!(
          agency: @agency, departure: departure, package: package, package_version: to,
          label: component.label, client_role: component.client_role,
          calculation_kind: component.calculation_kind, quantity_basis: component.quantity_basis,
          amount_minor_units: component.amount_minor_units, percentage_rate: component.percentage_rate,
          percentage_treatment: component.percentage_treatment, position: component.position
        )
      end
    end
  end
end
