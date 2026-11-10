# S-10: publishes a package to a reseller's channel, or withdraws it
# (DEP-07, DEP-09). Needs Departure management. A refusal returns to the
# package with its reason.
class OfferingPublicationsController < ApplicationController
  include PackageAccess

  before_action :require_departure_view!
  before_action -> { require_permission!(:publish_offerings) }
  before_action :set_departure
  before_action :set_offering

  def create
    reseller = Current.agency.resellers.find(params[:reseller_id])
    PublishOffering.new(agency: Current.agency, actor: Current.agency_user, offering: @offering, reseller:).call
    redirect_to channels_path, notice: "#{@offering.name} published to #{reseller.name}."
  rescue AgencyCommand::Error => error
    redirect_to channels_path, alert: error.message
  end

  def destroy
    publication = @offering.publications.find(params[:id])
    WithdrawOffering.new(agency: Current.agency, actor: Current.agency_user, publication:).call
    redirect_to channels_path, notice: "#{@offering.name} withdrawn from #{publication.reseller.name}."
  rescue AgencyCommand::Error => error
    redirect_to channels_path, alert: error.message
  end

  private

  def channels_path = departure_offerings_path(@departure, anchor: "channels-#{@offering.id}")
end
