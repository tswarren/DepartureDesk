# The client payment schedule template's lines (CMN-09, D-77, BKG-41).
class ClientScheduleLinesController < ApplicationController
  include PackageAccess

  FIELDS = %i[description basis service_category amount percentage due_rule days_before_departure due_on counts_as_acceptance].freeze
  LABELS = [ [ :description, "Description" ], [ :amount, "Amount" ], [ :percentage, "Percentage" ],
             [ :days_before_departure, "Days before departure" ], [ :due_on, "Due date" ], [ :service_category, "Service category" ] ].freeze

  before_action :require_departure_view!
  before_action :require_package_management!
  before_action :set_departure
  before_action :set_terms_version
  before_action :set_line, only: %i[edit update destroy]

  def new
    @line = @terms_version.schedule_lines.new(basis: "per_unit", due_rule: "at_confirmation")
    @values = {}
  end

  def create
    SaveClientScheduleLine.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, terms_version: @terms_version, attributes: line_params).call
    redirect_to departure_client_terms_path(@departure, anchor: "payment-schedule"), notice: "Schedule line saved."
  rescue AgencyCommand::Error => error
    @line = @terms_version.schedule_lines.new(line_params.slice("description", "basis", "due_rule").select { |_k, v| v.present? })
    @values = line_params
    render_form_error(error, @line, :new, LABELS)
  end

  def edit
    currency = @departure.operating_currency
    @values = {
      "amount" => MoneyInput.display(@line.amount_minor_units, currency), "percentage" => @line.percentage&.to_s("F"),
      "days_before_departure" => @line.days_before_departure, "due_on" => @line.due_on, "service_category" => @line.service_category,
      "counts_as_acceptance" => @line.counts_as_acceptance
    }
  end

  def update
    SaveClientScheduleLine.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, terms_version: @terms_version, line: @line,
      attributes: line_params, lock_version: params.dig(:client_payment_schedule_line, :lock_version)).call
    redirect_to departure_client_terms_path(@departure, anchor: "payment-schedule"), notice: "Schedule line saved."
  rescue AgencyCommand::Error => error
    @values = line_params
    render_form_error(error, @line, :edit, LABELS)
  end

  def destroy
    RemoveClientScheduleLine.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, terms_version: @terms_version, line: @line).call
    redirect_to departure_client_terms_path(@departure, anchor: "payment-schedule"), notice: "Schedule line removed."
  rescue AgencyCommand::Error => error
    redirect_to departure_client_terms_path(@departure, anchor: "payment-schedule"), alert: error.message
  end

  private

  def set_line
    @line = @terms_version.schedule_lines.find(params[:id])
  end

  def line_params = form_params(:client_payment_schedule_line, FIELDS)
end
