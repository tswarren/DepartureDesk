require "test_helper"

class PackagesRequestTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @viewer = agency_users(:harbor_viewer)
    @departure = create_capacity_departure(@agency, name: "Request Package Departure")
  end

  test "staff can make a package and viewer cannot see draft UI" do
    sign_in_as @staff
    get new_departure_package_path(@departure)
    assert_response :success
    assert_select "h1.dd-page-title", text: "Make Package"

    post departure_packages_path(@departure), params: {
      idempotency_key: SecureRandom.uuid,
      package: { name: "Weekend package" }
    }
    package = @departure.packages.find_by!(name: "Weekend package")
    assert_redirected_to departure_package_path(@departure, package)

    get departure_package_path(@departure, package)
    assert_response :success
    assert_match "Publish freezes this version", response.body
    assert_select "input[type=submit][value=Publish]", count: 1
    assert_match "No published reusable versions", response.body

    sign_in_as @viewer
    get departure_packages_path(@departure)
    assert_response :not_found
    get departure_package_path(@departure, package)
    assert_response :not_found
  end
end
