class Current < ActiveSupport::CurrentAttributes
  attribute :session

  delegate :user, to: :session, allow_nil: true

  def agency_membership
    user&.usable_agency_membership
  end

  def agency
    agency_membership&.agency
  end
end
