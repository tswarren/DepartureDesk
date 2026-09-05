class Current < ActiveSupport::CurrentAttributes
  attribute :session

  delegate :user, to: :session, allow_nil: true

  def agency_membership
    user&.usable_agency_membership
  end

  def agency
    agency_membership&.agency
  end

  def office
    membership = agency_membership
    return unless session && membership && agency

    if session.office_id
      stored = agency.offices.find_by(id: session.office_id)
      return stored if stored&.active? && membership.can_access_office?(stored)
    end

    default = membership.default_office
    return default if default&.active? && membership.can_access_office?(default)

    offices = membership.accessible_offices.limit(2).to_a
    offices.first if offices.one?
  end
end
