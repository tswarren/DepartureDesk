module Authentication
  extend ActiveSupport::Concern

  GENERIC_FAILURE = AgencyCommand::GENERIC_FAILURE

  included do
    before_action :resume_session
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private

  def authenticated?
    resume_session
  end

  def require_authentication
    resume_session || request_authentication
  end

  def resume_session
    return Current.session if Current.session&.current?

    presented_session_id = cookies.signed[:session_id]
    Current.session = find_session_by_cookie if presented_session_id
    return Current.session if Current.session&.current?

    reject_stale_session if presented_session_id
    nil
  end

  def find_session_by_cookie
    return unless cookies.signed[:session_id]

    Session.includes(agency_user: [ :agency, :default_office ], office: []).find_by(id: cookies.signed[:session_id])
  end

  def reject_stale_session
    Current.session&.destroy
    Current.session = nil
    cookies.delete(:session_id)
  end

  def request_authentication
    session[:return_to_after_authenticating] = request.url
    redirect_to new_session_path
  end

  def after_authentication_url
    session.delete(:return_to_after_authenticating) || root_url
  end

  def start_new_session_for(agency_user)
    agency_user.sessions.create!(
      user_agent: request.user_agent,
      ip_address: request.remote_ip,
      credential_version: agency_user.credential_version,
      office: initial_office_for(agency_user)
    ).tap do |record|
      Current.session = record
      cookies.signed.permanent[:session_id] = { value: record.id, httponly: true, same_site: :lax }
    end
  end

  def initial_office_for(agency_user)
    office = agency_user.default_office
    office if office&.active? && office.agency_id == agency_user.agency_id
  end

  def terminate_session
    Current.session&.destroy
    Current.session = nil
    cookies.delete(:session_id)
  end

  def require_permission!(permission)
    return if Current.agency_user&.permitted?(permission)

    redirect_to root_path, alert: AgencyCommand::UNAUTHORIZED
  end
end
