module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_agency_user, :current_agency

    def connect
      session = Session.includes(agency_user: :agency).find_by(id: cookies.signed[:session_id])
      reject_unauthorized_connection unless session&.current?

      self.current_agency_user = session.agency_user
      self.current_agency = session.agency_user.agency
    end
  end
end
