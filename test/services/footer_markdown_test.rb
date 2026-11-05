require "test_helper"

# SET-07: footers render only the allowed Markdown.
class FooterMarkdownTest < ActiveSupport::TestCase
  test "renders paragraphs, line breaks, emphasis, lists and web links" do
    html = FooterMarkdown.render("Thanks for **sailing**, *friend*.\nSee you soon.\n\n- One\n- Two\n\n1. First\n\n[Terms](https://harbor.example/terms)")

    assert_includes html, "<strong>sailing</strong>"
    assert_includes html, "<em>friend</em>"
    assert_includes html, "<br>"
    assert_includes html, "<ul>"
    assert_includes html, "<ol>"
    assert_includes html, %(<a href="https://harbor.example/terms">Terms</a>)
  end

  test "strips headings, tables, images, raw HTML and unsafe links" do
    html = FooterMarkdown.render(<<~MARKDOWN)
      # Heading

      | a | b |
      |---|---|
      | 1 | 2 |

      ![logo](https://harbor.example/logo.png)

      <script>alert(1)</script><iframe src="https://x.example"></iframe>

      [bad](javascript:alert(1))
    MARKDOWN

    assert_no_match(/<h1|<table|<img|<script|<iframe|javascript:/i, html)
    assert_includes html, "Heading"
    assert_includes html, "bad"
  end

  test "blank source renders nothing" do
    assert_equal "", FooterMarkdown.render(nil)
    assert_equal "", FooterMarkdown.render("  ")
  end
end
