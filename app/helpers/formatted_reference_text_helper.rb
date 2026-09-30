# frozen_string_literal: true

# Renders authored Supplier wording. The stored column remains the source.
module FormattedReferenceTextHelper
  REFERENCE_TAGS = %w[p br ul ol li strong em a].freeze
  REFERENCE_ATTRIBUTES = %w[href].freeze

  def formatted_reference_text(source)
    text = source.to_s
    return "".html_safe if text.strip.blank?

    rendered = Commonmarker.to_html(
      text,
      options: {
        parse: { smart: false },
        render: { unsafe: false, hardbreaks: true },
        extension: {
          table: false,
          autolink: false,
          strikethrough: false,
          tagfilter: true,
          tasklist: false
        }
      }
    )
    sanitize(rendered, tags: REFERENCE_TAGS, attributes: REFERENCE_ATTRIBUTES)
  end
end
