require "test_helper"

class CurrentOfficeTest < ActiveSupport::TestCase
  test "an agency with no active office leaves current office nil" do
    user = agency_users(:harbor_admin)
    agencies(:harbor).offices.update_all(status: "inactive")
    user.update!(default_office: nil)
    session = user.sessions.create!(credential_version: user.credential_version, office: nil)
    Current.session = session

    assert_nil Current.office
    assert user.reload.active?
  end

  test "selecting an office does not change permissions" do
    user = agency_users(:harbor_viewer)
    session = user.sessions.create!(credential_version: user.credential_version)
    before = AccessPermission::CATALOG.select { |_permission, roles| roles.include?(user.access_role) }.keys

    SelectCurrentOffice.new(session: session, office: offices(:harbor_west)).call

    assert_equal offices(:harbor_west), session.reload.office
    assert_equal before, AccessPermission::CATALOG.select { |_permission, roles| roles.include?(user.reload.access_role) }.keys
  end
end
