require "test_helper"

class SoleEditableDraftAccessTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_admin)
    @departure = create_capacity_departure(@agency, name: "Successor access")
    @departure.update!(
      status: "active", departure_reference: "D-930002", first_activated_at: 3.days.ago
    )
    @contractor = create_capacity_supplier(@agency, "Access Contractor")
    @arrangement = @agency.supplier_arrangements.create!(
      departure: @departure, contracting_supplier: @contractor, name: "Access Arrangement"
    )
    activated = @arrangement.versions.create!(
      agency: @agency, departure: @departure, version_number: 1,
      status: "activated", activated_at: 1.day.ago
    )
    @draft = @arrangement.versions.create!(
      agency: @agency, departure: @departure, version_number: 2,
      status: "draft", copied_from: activated
    )
    @arrangement.update!(status: "active", governing_version: activated)
  end

  test "arrangement access loads the sole editable draft" do
    sign_in_as @actor

    get departure_arrangement_path(@departure, @arrangement)

    assert_response :success
    assert_select "dd", text: "Draft version 2"
  end

  test "only initial version creation may select version number one operationally" do
    references = Dir[Rails.root.join("app/**/*.{rb,erb}")].flat_map do |path|
      File.readlines(path).filter_map do |line|
        next unless line.match?(/version_number\s*(?:==|:)\s*1|find_by!?\([^\n]*version_number:\s*1/)

        "#{Pathname(path).relative_path_from(Rails.root)}:#{line.strip}"
      end
    end

    assert_equal [
      "app/services/arrangement_command_support.rb:version_number: 1,",
      "app/services/connect_cruise_service_offer.rb:version_number: 1,",
      "app/services/create_initial_package_with_outline_service_offer.rb:version_number: 1,",
      "app/services/create_initial_package_with_outline_service_offer.rb:version_number: 1,",
      "app/services/create_package_draft.rb:version_number: 1,",
      "app/services/create_package_inline_service_offer.rb:version_number: 1,",
      "app/services/create_package_inline_service_offer.rb:version_number: 1,",
      "app/services/create_service_offer_from_source.rb:version_number: 1,",
      "app/services/create_service_offer_outline.rb:version_number: 1,",
      "app/services/create_service_offer_with_explicit_basis.rb:version_number: 1,"
    ], references
  end
end
