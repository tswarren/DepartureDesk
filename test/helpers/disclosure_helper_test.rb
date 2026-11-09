require "test_helper"

# UX consolidation audit B4: one disclosure, with a summary and a body.
class DisclosureHelperTest < ActionView::TestCase
  include ApplicationHelper

  test "a disclosure is closed by default and wraps its body" do
    html = Nokogiri::HTML.fragment(disclosure("Use the supplier's time zone") { "Fields" })
    details = html.at_css("details.dd-disclosure")

    assert_nil details["open"]
    assert_equal "Use the supplier's time zone", details.at_css("summary").text
    assert_equal "Fields", details.at_css(".dd-disclosure-body").text
  end

  test "a disclosure opens when told and keeps an extra class" do
    html = Nokogiri::HTML.fragment(disclosure("Change taxes or commission", open: true, class_name: "dd-rate-details") { "" })
    details = html.at_css("details")

    assert details.key?("open")
    assert_equal "dd-disclosure dd-rate-details", details["class"]
  end
end
