# Renders an agency footer's limited Markdown (SET-07): paragraphs, line
# breaks, bold, italic, bulleted and numbered lists and web links. Raw HTML is
# never rendered, and anything else is reduced to its text.
class FooterMarkdown
  TAGS = %w[p br strong em ul ol li a].freeze
  ATTRIBUTES = %w[href].freeze
  LINK_PROTOCOLS = %w[http https mailto].freeze

  def self.render(source)
    return "" if source.blank?

    html = Commonmarker.to_html(
      source.to_s,
      options: { render: { unsafe: false, hardbreaks: true }, extension: { autolink: true, table: false, strikethrough: false, tagfilter: true } },
      plugins: { syntax_highlighter: nil }
    )
    sanitizer.sanitize(html, tags: TAGS, attributes: ATTRIBUTES).then { |safe| strip_unsafe_links(safe) }.strip.html_safe
  end

  def self.sanitizer
    @sanitizer ||= Rails::HTML5::SafeListSanitizer.new
  end

  def self.strip_unsafe_links(html)
    fragment = Nokogiri::HTML5.fragment(html)
    fragment.css("a").each do |link|
      scheme = link["href"].to_s[/\A\s*([a-z][a-z0-9+.-]*):/i, 1]&.downcase
      link.replace(link.children) unless scheme.in?(LINK_PROTOCOLS)
    end
    fragment.to_html
  end
  private_class_method :sanitizer, :strip_unsafe_links
end
