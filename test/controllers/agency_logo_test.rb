require "test_helper"

# SET-08 logo, stored with Active Storage and served only through the
# application (ADR 0019).
class AgencyLogoTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
  end

  test "an agency admin uploads a logo and any signed-in agency user reads it" do
    sign_in_as @admin
    assert_difference -> { AuditEvent.where(action: "agency.logo_updated").count }, 1 do
      patch administration_agency_logo_path, params: { agency: { logo: logo_upload } }
    end
    assert_redirected_to administration_agency_path
    assert @agency.reload.logo.attached?

    sign_in_as agency_users(:harbor_baseline_staff)
    get agency_logo_path
    assert_response :success
    assert_equal "image/png", response.media_type
    assert_equal File.binread(file_fixture("logo.png")), response.body
    assert_match(/sandbox/, response.headers["Content-Security-Policy"])
  end

  test "staff cannot upload or remove the logo" do
    sign_in_as agency_users(:harbor_staff)
    patch administration_agency_logo_path, params: { agency: { logo: logo_upload } }
    assert_redirected_to root_path
    assert_not @agency.reload.logo.attached?
  end

  test "a file that is not an image is refused whatever its name or declared type" do
    sign_in_as @admin
    patch administration_agency_logo_path, params: {
      agency: { logo: fixture_file_upload("not_an_image.png", "image/png") }
    }
    assert_redirected_to edit_administration_agency_path
    assert_match(/PNG, JPEG or WebP/, flash[:alert])
    assert_not @agency.reload.logo.attached?
  end

  test "a logo larger than 2 MB is refused" do
    large = Tempfile.new([ "large", ".png" ], binmode: true)
    large.write(File.binread(file_fixture("logo.png")) + ("\0" * (Agency::LOGO_MAX_BYTES + 1)))
    large.rewind
    error = assert_raises(AgencyCommand::Error) do
      UpdateAgencyLogo.new(agency: @agency, actor: @admin, upload: Rack::Test::UploadedFile.new(large.path, "image/png")).call
    end
    assert_match(/2 MB/, error.message)
    assert_not @agency.reload.logo.attached?
  ensure
    large&.close!
  end

  test "removing the logo is audited and the download is then not found" do
    UpdateAgencyLogo.new(agency: @agency, actor: @admin, upload: logo_upload).call
    sign_in_as @admin
    assert_difference -> { AuditEvent.where(action: "agency.logo_removed").count }, 1 do
      perform_enqueued_jobs { delete administration_agency_logo_path }
    end
    assert_not @agency.reload.logo.attached?

    get agency_logo_path
    assert_response :not_found
  end

  test "the logo is not reachable signed out or through Active Storage routes" do
    UpdateAgencyLogo.new(agency: @agency, actor: @admin, upload: logo_upload).call

    get agency_logo_path
    assert_redirected_to new_session_path
    assert_not Rails.application.routes.url_helpers.respond_to?(:rails_blob_path)
    assert Rails.application.routes.routes.none? { |route| route.path.spec.to_s.start_with?("/rails/active_storage") }
  end

  test "another agency's logo is never served" do
    UpdateAgencyLogo.new(agency: agencies(:cove), actor: agency_users(:cove_admin), upload: logo_upload).call
    sign_in_as @admin
    get agency_logo_path
    assert_response :not_found
  end

  private

  def logo_upload
    fixture_file_upload("logo.png", "image/png")
  end
end
