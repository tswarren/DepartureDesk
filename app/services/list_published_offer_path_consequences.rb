# frozen_string_literal: true

class ListPublishedOfferPathConsequences
  Consequence = Data.define(:kind, :offer_type, :offer_id, :offer_name, :version_id, :message, :alternative_remains)

  def initialize(agency:, arrangement: nil, supplier: nil)
    @agency = agency
    @arrangement = arrangement
    @supplier = supplier
  end

  def call
    rows = []
    ServiceOfferSourceBinding
      .joins(:service_offer_version)
      .where(agency_id: @agency.id)
      .where(service_offer_versions: { status: "published" })
      .includes(:service_offer, :service_offer_version, :supplier_arrangement)
      .find_each do |binding|
        next unless matches?(binding)

        version = binding.service_offer_version
        offer = binding.service_offer
        alt_ok = alternative_remains?(version, binding)
        rows << Consequence.new(
          kind: @arrangement ? "arrangement_ending" : "supplier_inactivation",
          offer_type: "ServiceOffer",
          offer_id: offer.id,
          offer_name: offer.name,
          version_id: version.id,
          message: "Published service #{offer.name} path may become unavailable.",
          alternative_remains: alt_ok
        )
      end

    PackageInclusion
      .joins(:service_offer_version, :package_version)
      .where(agency_id: @agency.id)
      .where(package_versions: { status: "published" })
      .includes(package_version: :package, service_offer_version: :source_bindings)
      .find_each do |inclusion|
        next unless inclusion.service_offer_version.source_bindings.any? { |binding| matches?(binding) }

        package = inclusion.package_version.package
        rows << Consequence.new(
          kind: @arrangement ? "arrangement_ending" : "supplier_inactivation",
          offer_type: "Package",
          offer_id: package.id,
          offer_name: package.name,
          version_id: inclusion.package_version_id,
          message: "Published package #{package.name} may lose a selectable path.",
          alternative_remains: false
        )
      end

    rows.uniq { |row| [ row.offer_type, row.offer_id, row.version_id ] }
  end

  private

  def matches?(binding)
    if @arrangement
      binding.supplier_arrangement_id == @arrangement.id
    elsif @supplier
      binding.supplier_arrangement.contracting_supplier_id == @supplier.id
    else
      false
    end
  end

  def alternative_remains?(version, affected)
    return false unless affected.alternative?

    version.source_bindings.where(membership_kind: "alternative", alternative_group_key: affected.alternative_group_key)
      .where.not(id: affected.id)
      .any? { |binding| !matches?(binding) }
  end
end
