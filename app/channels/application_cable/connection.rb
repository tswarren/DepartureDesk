module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :current_agency

    def connect
      session = Session.includes(
        user: { active_agency_memberships: :agency }
      ).find_by(id: cookies.signed[:session_id])

      membership = session&.user&.usable_agency_membership
      reject_unauthorized_connection unless membership

      self.current_user = session.user
      self.current_agency = membership.agency
    end
  end
end
