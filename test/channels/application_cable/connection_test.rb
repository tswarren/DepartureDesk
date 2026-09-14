require "test_helper"

module ApplicationCable
  class ConnectionTest < ActionCable::Connection::TestCase
    test "connects with an active agency user" do
      session = agency_users(:harbor_admin).sessions.create!(credential_version: 1)
      cookies.signed[:session_id] = session.id

      connect

      assert_equal agency_users(:harbor_admin), connection.current_agency_user
      assert_equal agencies(:harbor), connection.current_agency
    end

    test "rejects a missing session" do
      cookies.signed[:session_id] = SecureRandom.uuid_v7

      assert_reject_connection { connect }
    end

    test "rejects a suspended agency user" do
      user = agency_users(:harbor_suspended)
      cookies.signed[:session_id] = user.sessions.create!(credential_version: user.credential_version).id

      assert_reject_connection { connect }
    end

    test "rejects a suspended agency" do
      agencies(:harbor).update!(status: :suspended)
      user = agency_users(:harbor_admin)
      cookies.signed[:session_id] = user.sessions.create!(credential_version: user.credential_version).id

      assert_reject_connection { connect }
    end
  end
end
