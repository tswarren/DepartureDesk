# Serves the signed-in agency's logo (SET-08). Active Storage's own routes are
# off (ADR 0019), so this is the only way to read the file.
class AgencyLogosController < ApplicationController
  before_action -> { require_permission!(:view_workspace) }

  def show
    logo = Current.agency.logo
    raise ActiveRecord::RecordNotFound unless logo.attached?

    response.headers["Content-Security-Policy"] = "default-src 'none'; sandbox"
    send_data logo.download,
      filename: logo.filename.to_s,
      type: logo.content_type,
      disposition: "inline"
  end
end
