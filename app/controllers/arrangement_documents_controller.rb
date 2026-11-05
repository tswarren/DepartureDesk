# Supplier documents on an arrangement (ADR 0019 amendment). Viewing and
# downloading need view_supplier_costs (ACC-31); uploading and removing need
# manage_arrangements. Active Storage's own routes stay off.
class ArrangementDocumentsController < ApplicationController
  include ArrangementAccess

  before_action :require_arrangement_view!
  before_action -> { require_permission!(:view_supplier_costs) }, only: :show
  before_action :require_arrangement_management!, except: :show
  before_action :set_departure
  before_action :set_arrangement
  before_action :set_document, only: %i[show destroy]

  def show
    file = @document.file
    data = file.download
    raise "Arrangement document #{@document.id} failed its SHA-256 check" unless Digest::SHA256.hexdigest(data) == @document.sha256

    response.headers["Content-Security-Policy"] = "default-src 'none'; sandbox"
    send_data data, filename: file.filename.to_s, type: file.content_type,
      disposition: @document.office? ? "attachment" : "inline"
  end

  def create
    UploadArrangementDocument.new(
      agency: Current.agency, actor: Current.agency_user, departure: @departure, arrangement: @arrangement,
      upload: params.dig(:arrangement_document, :file), kind: params.dig(:arrangement_document, :kind),
      description: params.dig(:arrangement_document, :description)
    ).call
    redirect_to departure_arrangement_path(@departure, @arrangement, anchor: "documents"), notice: "Document added."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to departure_arrangement_path(@departure, @arrangement, anchor: "documents"), alert: error.message
  end

  def destroy
    RemoveArrangementDocument.new(
      agency: Current.agency, actor: Current.agency_user, departure: @departure, arrangement: @arrangement, document: @document
    ).call
    redirect_to departure_arrangement_path(@departure, @arrangement, anchor: "documents"), notice: "Document removed."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to departure_arrangement_path(@departure, @arrangement, anchor: "documents"), alert: error.message
  end

  private

  def set_document
    @document = @arrangement.documents.find(params[:id])
  end
end
