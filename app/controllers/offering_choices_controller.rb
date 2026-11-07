class OfferingChoicesController < ApplicationController
  include PackageAccess

  FIELDS = %i[name role scope pattern].freeze

  before_action :require_departure_view!
  before_action :require_package_management!
  before_action :set_departure
  before_action :set_offering
  before_action :set_choice, only: %i[edit update destroy]

  def new
    @choice = @offering.choices.new(role: "included", scope: "per_unit", pattern: "required_single")
  end

  def create
    SaveOfferingChoice.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, offering: @offering, attributes: choice_params).call
    redirect_to departure_offerings_path(@departure), notice: "Choice added."
  rescue AgencyCommand::Error => error
    @choice = @offering.choices.new(choice_params.slice("name").merge(choice_params.slice("role", "scope", "pattern").select { |_k, v| v.present? }))
    render_form_error(error, @choice, :new, [ [ :name, "Name" ], [ :pattern, "Pattern" ] ])
  end

  def edit
  end

  def update
    SaveOfferingChoice.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, offering: @offering, choice: @choice,
      attributes: choice_params, lock_version: params.dig(:offering_choice, :lock_version)).call
    redirect_to departure_offerings_path(@departure), notice: "Choice updated."
  rescue AgencyCommand::Error => error
    render_form_error(error, @choice, :edit, [ [ :name, "Name" ], [ :pattern, "Pattern" ] ])
  end

  def destroy
    RemoveOfferingChoice.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, offering: @offering, choice: @choice).call
    redirect_to departure_offerings_path(@departure), notice: "Choice removed."
  end

  private

  def set_choice
    @choice = @offering.choices.find(params[:choice_id] || params[:id])
  end

  def choice_params = form_params(:offering_choice, FIELDS)
end
