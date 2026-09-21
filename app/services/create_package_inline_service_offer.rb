# frozen_string_literal: true

class CreatePackageInlineServiceOffer < AgencyCommand
  include PackageCommandSupport

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
      package_row = @agency.packages.find_by(id: record_id(@package))
      raise Error.new("That package was not found.", code: :not_found) if package_row.nil?

      pin = nil
      planning_version = nil
      arrangement = nil
      if from_source?
        arrangement = @agency.supplier_arrangements.find_by(id: @attributes[:supplier_arrangement_id])
        raise Error.new("That supplier arrangement was not found.", code: :not_found) if arrangement.nil?
        raise Error.new("That supplier arrangement was not found.", code: :not_found) if arrangement.departure_id != package_row.departure_id

        planning_version = resolve_planning_version!(
          arrangement,
          requested_version_id: @attributes[:supplier_arrangement_version_id],
          use_tentative_draft: boolean_flag(@attributes[:use_tentative_draft])
        )
        item_definition = planning_version.arrangement_item_definitions.find_by(
          arrangement_item_id: @attributes[:arrangement_item_id]
        )
        occurrence_definition = if @attributes[:service_occurrence_id].present?
          planning_version.service_occurrence_definitions.find_by(
            service_occurrence_id: @attributes[:service_occurrence_id]
          )
        end
        provider = effective_provider_for(arrangement, item_definition, occurrence_definition) if item_definition
        lock_suppliers_in_uuid_order!(arrangement.contracting_supplier_id, provider&.id)
      end

      departure = lock_departure_for!(package_row.departure_id)
      if from_source?
        arrangement = lock_arrangement_for!(arrangement)
        planning_version = arrangement.versions.lock.find(planning_version.id)
        pin = resolve_source_pin!(arrangement:, version: planning_version, attributes: @attributes)
      end
      package = lock_package_for!(package_row)
      version = lock_editable_package_draft!(package)
      ensure_package_draft_editable!(departure, package, version)
      ensure_departure_accepts_new_offer!(departure)
      ensure_current_lock_version!(version, @version_lock_version)

      unless from_source?
        basis = @attributes[:fulfillment_basis].to_s
        unless ServiceOfferDefinition::FULFILLMENT_BASES.include?(basis) && basis != "m3_backed"
          raise Error.new("Choose on request, Agency fulfilled, or externally fulfilled.", code: :invalid)
        end
      end

      placement = normalize_placement(@attributes[:placement])
      payload = digest_payload(pin, from_source? ? nil : @attributes[:fulfillment_basis], placement)

      idempotent_create!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload: payload.merge(package_id: package.id, package_version_id: version.id),
        result_class: Package
      ) do
        offer = create_owned_offer!(departure, version, pin, placement)
        bump_version!(version)
        audit!(
          agency: @agency,
          action: "package.service_included",
          subject: package,
          actor: @actor,
          details: package_audit_details(package, version, "service_offer_id" => offer.id, "origin" => "inline_create")
        )
        package.reload
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def from_source?
    @attributes[:supplier_arrangement_id].present? || @attributes[:fulfillment_basis].blank?
  end

  def record_id(record)
    record.respond_to?(:id) ? record.id : record
  end

  def normalize_placement(value)
    placement = value.to_s.presence || "included"
    unless PackageInclusion::PLACEMENTS.include?(placement)
      raise Error.new("Choose included or optional placement.", code: :invalid)
    end

    placement
  end

  def digest_payload(pin, basis, placement)
    if pin
      {
        origin: "inline_create",
        placement: placement,
        supplier_arrangement_id: pin[:arrangement].id,
        supplier_arrangement_version_id: pin[:version].id,
        arrangement_item_id: pin[:item].id,
        service_occurrence_id: pin[:occurrence]&.id,
        supplier_resource_id: pin[:resource]&.id,
        capacity_pool_id: pin[:pool]&.id,
        name: normalize_offer_name(@attributes[:name].presence || @attributes[:client_title].presence || source_name_for(pin)),
        client_title: normalize_client_title(@attributes[:client_title].presence || source_name_for(pin))
      }
    else
      client_title = normalize_client_title(@attributes[:client_title].presence || @attributes[:name])
      {
        origin: "inline_create",
        placement: placement,
        fulfillment_basis: basis,
        name: normalize_offer_name(@attributes[:name].presence || client_title),
        client_title: client_title
      }
    end
  end

  def create_owned_offer!(departure, package_version, pin, placement)
    if pin
      source_name = source_name_for(pin)
      client_title = @attributes[:client_title].presence || source_name
      client_description = @attributes.key?(:client_description) ? @attributes[:client_description] : source_description_for(pin)
      display_name = @attributes[:name].presence || client_title
      title_provenance = @attributes[:client_title].present? ? "staff_entered" : "source_name"
      description_provenance =
        if @attributes.key?(:client_description)
          @attributes[:client_description].present? ? "staff_entered" : "none"
        elsif source_description_for(pin).present?
          "source_description"
        else
          "none"
        end
      offer = @agency.service_offers.create!(
        departure: departure,
        name: normalize_offer_name(display_name)
      )
      offer_version = offer.versions.create!(
        agency: @agency,
        departure: departure,
        version_number: 1,
        status: "draft",
        owning_package_version: package_version
      )
      offer_version.create_definition!(
        agency: @agency,
        departure: departure,
        service_offer: offer,
        client_title: normalize_client_title(client_title),
        client_description: normalize_client_description(client_description),
        fulfillment_basis: "m3_backed"
      )
      offer_version.source_bindings.create!(
        binding_attributes_from_pin(
          pin,
          membership: "required",
          position: 1,
          dependencies: {
            client_title_provenance: title_provenance,
            client_description_provenance: description_provenance
          }
        ).merge(service_offer: offer)
      )
    else
      basis = @attributes[:fulfillment_basis].to_s
      client_title = normalize_client_title(@attributes[:client_title].presence || @attributes[:name])
      offer = @agency.service_offers.create!(
        departure: departure,
        name: normalize_offer_name(@attributes[:name].presence || client_title)
      )
      offer_version = offer.versions.create!(
        agency: @agency,
        departure: departure,
        version_number: 1,
        status: "draft",
        owning_package_version: package_version
      )
      offer_version.create_definition!(
        agency: @agency,
        departure: departure,
        service_offer: offer,
        client_title: client_title,
        client_description: normalize_client_description(@attributes[:client_description]),
        fulfillment_basis: basis
      )
    end

    package_version.inclusions.create!(
      agency: @agency,
      departure: departure,
      package: package_version.package,
      service_offer: offer,
      service_offer_version: offer_version,
      placement: placement,
      origin: "inline_create",
      position: next_inclusion_position(package_version)
    )
    audit!(
      agency: @agency,
      action: "service_offer.created",
      subject: offer,
      actor: @actor,
      details: {
        "service_offer_id" => offer.id,
        "service_offer_version_id" => offer_version.id,
        "departure_id" => departure.id,
        "package_id" => package_version.package_id,
        "origin" => "inline_create"
      }
    )
    offer
  end
end
