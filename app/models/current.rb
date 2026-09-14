class Current < ActiveSupport::CurrentAttributes
  attribute :session

  def agency_user
    session&.agency_user
  end

  def agency
    agency_user&.agency
  end

  def office
    return unless session && agency_user&.active? && agency&.active?

    stored = session.office
    return stored if stored&.active? && stored.agency_id == agency.id

    default = agency_user.default_office
    return default if default&.active? && default.agency_id == agency.id

    nil
  end
end
