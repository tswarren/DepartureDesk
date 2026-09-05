require "test_helper"

module ApplicationCable
  class ConnectionTest < ActionCable::Connection::TestCase
    test "connects with an active membership and agency" do
      session = users(:one).sessions.create!
      cookies.signed[:session_id] = session.id

      connect

      assert_equal users(:one), connection.current_user
      assert_equal agencies(:one), connection.current_agency
    end

    test "rejects a missing membership" do
      user = User.create!(
        email_address: "cable-none@example.com",
        password: "password",
        password_confirmation: "password"
      )
      cookies.signed[:session_id] = user.sessions.create!.id

      assert_reject_connection { connect }
    end

    test "rejects a suspended membership" do
      agency_memberships(:one).update!(status: :suspended)
      cookies.signed[:session_id] = users(:one).sessions.create!.id

      assert_reject_connection { connect }
    end

    test "rejects a suspended agency" do
      agencies(:one).update!(status: :suspended)
      cookies.signed[:session_id] = users(:one).sessions.create!.id

      assert_reject_connection { connect }
    end

    test "rejects a closed agency" do
      agencies(:one).update!(status: :closed)
      cookies.signed[:session_id] = users(:one).sessions.create!.id

      assert_reject_connection { connect }
    end
  end
end
