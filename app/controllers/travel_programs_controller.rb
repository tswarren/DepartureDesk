class TravelProgramsController < ApplicationController
  before_action :set_program, only: %i[show edit update deactivate reactivate]

  def index
    @today = DirectoryDate.today(Current.agency)
    @programs = Current.agency.travel_programs.order(:name)
    @program_summaries = DepartureQuery.new(
      agency: Current.agency,
      membership: Current.agency_membership
    ).upcoming_program_summaries(program_ids: @programs.map(&:id), on: @today)
  end

  def show
    @today = DirectoryDate.today(Current.agency)
    @query = DepartureQuery.new(agency: Current.agency, membership: Current.agency_membership)
    @departures = @query.for_program(@travel_program).includes(:office).order(:start_date, :departure_reference)
  end

  def new
    @travel_program = Current.agency.travel_programs.new
  end

  def create
    result = CreateTravelProgram.new(
      agency: Current.agency,
      actor: Current.user,
      name: program_params[:name],
      description: program_params[:description],
      client_facing_description: program_params[:client_facing_description]
    ).call
    redirect_to travel_program_path(result.travel_program), notice: "Travel program created."
  rescue MembershipCommand::Error => error
    @travel_program = Current.agency.travel_programs.new(program_params)
    flash.now[:alert] = error.message
    render :new, status: :unprocessable_entity
  end

  def edit
  end

  def update
    UpdateTravelProgram.new(
      agency: Current.agency,
      actor: Current.user,
      travel_program: @travel_program,
      name: program_params[:name],
      description: program_params[:description],
      client_facing_description: program_params[:client_facing_description],
      lock_version: program_params[:lock_version]
    ).call
    redirect_to travel_program_path(@travel_program), notice: "Travel program updated."
  rescue MembershipCommand::Error => error
    @travel_program.assign_attributes(program_params.except(:lock_version))
    flash.now[:alert] = error.message
    render :edit, status: error.code == :conflict ? :conflict : :unprocessable_entity
  end

  def deactivate
    DeactivateTravelProgram.new(
      agency: Current.agency,
      actor: Current.user,
      travel_program: @travel_program,
      reason: params[:reason],
      lock_version: params[:lock_version]
    ).call
    redirect_to travel_program_path(@travel_program), notice: "Travel program deactivated."
  rescue MembershipCommand::Error => error
    redirect_to travel_program_path(@travel_program), alert: error.message
  end

  def reactivate
    ReactivateTravelProgram.new(
      agency: Current.agency,
      actor: Current.user,
      travel_program: @travel_program,
      reason: params[:reason],
      lock_version: params[:lock_version]
    ).call
    redirect_to travel_program_path(@travel_program), notice: "Travel program reactivated."
  rescue MembershipCommand::Error => error
    redirect_to travel_program_path(@travel_program), alert: error.message
  end

  private

  def set_program
    @travel_program = Current.agency.travel_programs.find(params[:id])
  end

  def program_params
    params.require(:travel_program).permit(:name, :description, :client_facing_description, :lock_version)
  end
end
