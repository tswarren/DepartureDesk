require "test_helper"

# UX consolidation audit C1: a refused command re-renders its form with what
# was typed and one summary inside the form, never a redirect or a page banner.
class FormErrorRenderingTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as agency_users(:harbor_admin)
  end

  test "a refused office keeps what was typed and shows the summary on the form" do
    taken = offices(:harbor_main).code

    assert_no_difference -> { Office.count } do
      post administration_offices_path, params: { office: { name: "Harbor East", code: taken } }
    end

    assert_response :unprocessable_entity
    assert_select "form #form-error-summary[role=alert]", text: /Code/
    assert_select "input[name='office[name]'][value='Harbor East']"
    assert_select "input[name='office[code]'][value='#{taken}']"
    assert_nil flash[:alert]
  end

  test "a refused client person shows the summary on the form instead of a banner" do
    post client_people_path, params: { client_person: { first_name: "", last_name: "Lovelace" } }

    assert_response :unprocessable_entity
    assert_select "form #form-error-summary[role=alert]"
    assert_select "input[name='client_person[last_name]'][value='Lovelace']"
    assert_nil flash[:alert]
  end

  test "refused terms wording keeps the wording typed and marks its field" do
    wording = "x" * (ClientTermsVersion::WORDING_LIMIT + 1)

    patch administration_client_terms_defaults_path, params: { agency: { client_terms_wording: wording, lock_version: agencies(:harbor).lock_version } }

    assert_response :unprocessable_entity
    assert_select "#form-error-summary a[href='#agency_client_terms_wording']", text: "Client terms wording is too long (#{ClientTermsVersion::WORDING_LIMIT} characters at most)."
    assert_select "textarea[name='agency[client_terms_wording]']", text: wording
    assert_not_equal wording, agencies(:harbor).reload.client_terms_wording
  end
end
