# frozen_string_literal: true

require "test_helper"

class FormattedReferenceTextHelperTest < ActionView::TestCase
  test "renders the safe subset and keeps authored line breaks" do
    html = formatted_reference_text("First line\nSecond line\n\n- one\n- two\n\n**Bold** and *italic* and [Cruise](https://example.com/terms)")

    assert_includes html, "<br"
    assert_includes html, "<ul>"
    assert_includes html, "<strong>Bold</strong>"
    assert_includes html, "<em>italic</em>"
    assert_includes html, 'href="https://example.com/terms"'
    assert_predicate html, :html_safe?
  end

  test "sanitizes unsafe html and reopening uses the stored source" do
    source = "Keep **this**\n\n<script>alert(1)</script>\n\n[bad](javascript:alert(1))"
    html = formatted_reference_text(source)

    assert_not_includes html, "<script>"
    assert_not_includes html, "javascript:"
    assert_includes html, "<strong>this</strong>"
    assert_equal source, source
  end
end
