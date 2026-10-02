# frozen_string_literal: true

class HotelAgreementTermsController < ApplicationController
  include HotelArrangementAccess

  before_action :require_departure_management!
  before_action :set_departure
  before_action :ensure_composable_departure!
  before_action :set_supplier_arrangement
  before_action :set_hotel_agreement_version
  before_action :set_lodging_hotel_item
  before_action :assign_hotel_composition_context
  before_action :require_editable_agreement!
  before_action :set_kind, only: %i[new create]
  before_action :set_reference, only: %i[edit update destroy]

  def new
    @idempotency_key = SecureRandom.uuid
    @scope = optional_kind? ? "stay" : nil
    apply_source_default
  end

  def create
    @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
    assign_fields_from_params
    RecordSupplierAgreementReference.new(**reference_command_attributes).call
    redirect_to hotel_agreement_path_for, notice: "Agreement term saved."
  rescue AgencyCommand::Error => error
    hotel_command_error(error, :new)
  end

  def edit
    @kind = @reference.kind
    @scope = @reference.arrangement_item_id.nil? ? "agreement" : "stay"
    @governing_wording = @reference.governing_wording
    @original_wording = @reference.original_wording
    @source_description = @reference.source_description
    @supplier_reference = @reference.supplier_reference
    @external_reference = @reference.external_reference
    @evidence_note = @reference.evidence_note
  end

  def update
    @kind = @reference.kind
    @scope = @reference.arrangement_item_id.nil? ? "agreement" : "stay"
    assign_fields_from_params
    RecordSupplierAgreementReference.new(
      **reference_command_attributes,
      lock_version: params[:lock_version]
    ).call
    redirect_to hotel_agreement_path_for, notice: "Agreement term saved."
  rescue AgencyCommand::Error => error
    hotel_command_error(error, :edit)
  end

  def destroy
    RemoveSupplierAgreementReference.new(
      agency: Current.agency,
      actor: Current.agency_user,
      reference: @reference,
      lock_version: params[:lock_version]
    ).call
    redirect_to hotel_agreement_path_for, notice: "Agreement term removed."
  rescue AgencyCommand::Error => error
    redirect_to hotel_agreement_path_for, alert: error.message
  end

  private

  def require_editable_agreement!
    raise ActiveRecord::RecordNotFound unless hotel_agreement_editable?
  end

  def set_kind
    @kind = params[:kind].to_s
    raise ActiveRecord::RecordNotFound unless SupplierAgreementReference::KINDS.include?(@kind)
  end

  def set_reference
    @reference = @supplier_arrangement_version.supplier_agreement_references.find(params[:id])
    return if @reference.arrangement_item_id.nil? || @reference.arrangement_item_id == @arrangement_item.id

    raise ActiveRecord::RecordNotFound
  end

  def optional_kind?
    SupplierAgreementReference::OPTIONAL_KINDS.include?(@kind)
  end

  def confirmed_version?
    SupplierConfirmation.exists?(supplier_arrangement_version_id: @supplier_arrangement_version.id)
  end
  helper_method :optional_kind?, :confirmed_version?

  def apply_source_default
    default = agreement_workspace.source_default
    return if default.nil?

    @source_description = default.source_description
    @supplier_reference = default.supplier_reference
    @external_reference = default.external_reference
    @evidence_note = default.evidence_note
  end

  def agreement_workspace
    HotelAgreementWorkspace.new(
      agency: Current.agency,
      departure: @departure,
      arrangement: @supplier_arrangement,
      version: @supplier_arrangement_version,
      item: @arrangement_item
    ).call
  end

  def assign_fields_from_params
    @governing_wording = params[:governing_wording]
    @original_wording = params[:original_wording]
    @source_description = params[:source_description]
    @supplier_reference = params[:supplier_reference]
    @external_reference = params[:external_reference]
    @evidence_note = params[:evidence_note]
    @scope = params[:scope].presence || @scope
  end

  def reference_command_attributes
    attributes = {
      agency: Current.agency,
      actor: Current.agency_user,
      kind: @kind,
      governing_wording: @governing_wording,
      original_wording: @original_wording,
      source_description: @source_description,
      supplier_reference: @supplier_reference,
      external_reference: @external_reference,
      evidence_note: @evidence_note,
      idempotency_key: @idempotency_key
    }
    if @scope == "agreement"
      attributes[:scope] = "agreement"
      attributes[:supplier_arrangement_version] = @supplier_arrangement_version
    else
      attributes[:arrangement_item] = @reference&.arrangement_item || @arrangement_item
      attributes[:scope] = "stay" if optional_kind? || @scope == "stay"
    end
    attributes
  end
end
