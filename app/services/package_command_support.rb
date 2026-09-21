# frozen_string_literal: true

module PackageCommandSupport
  extend ActiveSupport::Concern

  include OfferCommandSupport

  private

  def lock_package_for!(package)
    @agency.packages.lock.find(package.is_a?(Package) ? package.id : package)
  end

  def lock_editable_package_draft!(package)
    package.versions.lock.find_by(status: "draft") ||
      raise(AgencyCommand::Error.new("That package has no editable draft.", code: :invalid_state))
  end

  def lock_packages_in_uuid_order!(*packages)
    ids = packages.flatten.compact.map { |value| value.respond_to?(:id) ? value.id : value }.uniq.sort
    ids.map { |id| lock_package_for!(id) }
  end

  def lock_service_offers_in_uuid_order!(*offers)
    ids = offers.flatten.compact.map { |value| value.respond_to?(:id) ? value.id : value }.uniq.sort
    ids.map { |id| lock_offer_for!(id) }
  end

  def lock_departure_package_draft!(package)
    departure = lock_departure_for!(package.departure_id)
    locked_package = lock_package_for!(package)
    version = lock_editable_package_draft!(locked_package)
    [ departure, locked_package, version ]
  end

  def ensure_departure_accepts_new_package!(departure)
    return if departure.draft? || departure.active?

    raise AgencyCommand::Error.new("A departed departure cannot create packages.", code: :invalid_state) if departure.departed?

    raise AgencyCommand::Error.new("That departure cannot be edited.", code: :invalid_state)
  end

  def ensure_package_draft_editable!(departure, package, version)
    unless version.draft? && package.editable_draft_version&.id == version.id
      raise AgencyCommand::Error.new("That package cannot be edited.", code: :invalid_state)
    end
    return if departure.draft? || departure.active? || departure.departed?

    raise AgencyCommand::Error.new("That departure cannot be edited.", code: :invalid_state)
  end

  def normalize_package_name(value)
    name = value.to_s.strip
    raise AgencyCommand::Error.new("Enter a name.", code: :invalid) if name.blank?
    if name.length > Package::NAME_LIMIT
      raise AgencyCommand::Error.new("Name must be #{Package::NAME_LIMIT} characters or fewer.", code: :invalid)
    end

    name
  end

  def next_inclusion_position(version)
    (version.inclusions.maximum(:position) || 0) + 1
  end

  def package_audit_details(package, version, extra = {})
    {
      "package_id" => package.id,
      "package_version_id" => version.id,
      "departure_id" => package.departure_id
    }.merge(extra)
  end
end
