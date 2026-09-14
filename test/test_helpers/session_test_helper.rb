module SessionTestHelper
  def sign_in_as(agency_user)
    office = agency_user.default_office
    office = nil unless office&.active? && office.agency_id == agency_user.agency_id
    Current.session = agency_user.sessions.create!(
      credential_version: agency_user.credential_version,
      office: office
    )

    ActionDispatch::TestRequest.create.cookie_jar.tap do |cookie_jar|
      cookie_jar.signed[:session_id] = Current.session.id
      cookies["session_id"] = cookie_jar[:session_id]
    end
  end

  def sign_out
    Current.session&.destroy!
    cookies.delete("session_id")
  end

  def signed_session_cookie(session)
    ActionDispatch::TestRequest.create.cookie_jar.tap do |cookie_jar|
      cookie_jar.signed[:session_id] = session.id
    end[:session_id]
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include SessionTestHelper
end
