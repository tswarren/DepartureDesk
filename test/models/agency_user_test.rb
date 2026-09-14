require "test_helper"

class AgencyUserTest < ActiveSupport::TestCase
  test "a password of ten characters is accepted" do
    user = agency_users(:harbor_staff)
    user.password = "ten-chars!"
    user.password_confirmation = "ten-chars!"

    assert_predicate user, :valid?
  end

  test "a password shorter than ten characters is rejected" do
    user = agency_users(:harbor_staff)
    user.password = "ninechars"
    user.password_confirmation = "ninechars"

    assert_not user.valid?
    assert user.errors.of_kind?(:password, :too_short)
  end
end
