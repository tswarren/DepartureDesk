module Administration
  # Renders a footer preview for the agency profile editor (SET-07). Nothing
  # is saved.
  class FooterPreviewsController < BaseController
    def create
      html = FooterMarkdown.render(params[:source].to_s.first(10_000))
      render html: html.presence || helpers.tag.p("Nothing to show yet.", class: "dd-field-hint"), layout: false
    end
  end
end
