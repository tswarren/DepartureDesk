class Session < ApplicationRecord
  belongs_to :user
  belongs_to :office, optional: true

  def self.persist_initial_office!(session, user)
    membership = user.usable_agency_membership
    return session unless membership

    default = membership.default_office
    if default&.active? && membership.can_access_office?(default)
      session.update!(office: default)
      return session
    end

    offices = membership.accessible_offices.limit(2).to_a
    session.update!(office: offices.first) if offices.one?
    session
  end
end
