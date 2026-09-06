module Directory
  class ContactPointsController < ApplicationController
    before_action :set_party
    before_action :set_contact_point, only: %i[edit update deactivate reactivate suppress unsuppress set_primary]

    def new
      @contact_kind = params[:contact_kind].to_s
      unless PartyContactPoint::KINDS.include?(@contact_kind)
        redirect_to directory_party_contact_information_path(@party), alert: "Choose an email, phone, or postal address."
        return
      end
      @contact_point = @party.contact_points.new(contact_kind: @contact_kind, status: "active")
    end

    def create
      @contact_kind = contact_params[:contact_kind].to_s
      result = CreatePartyContactPoint.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        contact_kind: @contact_kind,
        label: contact_params[:label],
        attributes: detail_params
      ).call
      notice = result.status == :created ? "Contact information added." : "Contact information restored."
      redirect_to directory_party_contact_information_path(@party), notice:
    rescue MembershipCommand::Error => error
      @contact_point = @party.contact_points.new(contact_kind: @contact_kind, status: "active", label: contact_params[:label])
      flash.now[:alert] = error.message
      render :new, status: error.code == :conflict ? :conflict : :unprocessable_entity
    end

    def edit
    end

    def update
      UpdatePartyContactPoint.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        contact_point: @contact_point,
        label: contact_params[:label],
        attributes: detail_params,
        lock_version: contact_params[:lock_version]
      ).call
      redirect_to directory_party_contact_information_path(@party), notice: "Contact information updated."
    rescue MembershipCommand::Error => error
      flash.now[:alert] = error.message
      render :edit, status: error.code == :conflict ? :conflict : :unprocessable_entity
    end

    def deactivate
      DeactivatePartyContactPoint.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        contact_point: @contact_point,
        reason: lifecycle_params[:reason]
      ).call
      redirect_to directory_party_contact_information_path(@party), notice: "Contact information deactivated."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_contact_information_path(@party), alert: error.message
    end

    def reactivate
      ReactivatePartyContactPoint.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        contact_point: @contact_point
      ).call
      redirect_to directory_party_contact_information_path(@party), notice: "Contact information reactivated."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_contact_information_path(@party), alert: error.message
    end

    def suppress
      SuppressPartyContactPoint.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        contact_point: @contact_point,
        reason: lifecycle_params[:reason]
      ).call
      redirect_to directory_party_contact_information_path(@party), notice: "Contact information marked do not use."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_contact_information_path(@party), alert: error.message
    end

    def unsuppress
      UnsuppressPartyContactPoint.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        contact_point: @contact_point
      ).call
      redirect_to directory_party_contact_information_path(@party), notice: "Contact information may be used again."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_contact_information_path(@party), alert: error.message
    end

    def set_primary
      SetContactPointPrimary.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        contact_point: @contact_point,
        purpose: lifecycle_params[:purpose]
      ).call
      redirect_to directory_party_contact_information_path(@party), notice: "Primary contact updated."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_contact_information_path(@party), alert: error.message
    end

    private

    def set_party
      @party = Current.agency.parties.find(params[:party_id])
    end

    def set_contact_point
      @contact_point = @party.contact_points.find(params[:id])
    end

    def contact_params
      params.fetch(:party_contact_point, {}).permit(
        :contact_kind, :label, :lock_version,
        :display_address, :email_type,
        :display_number, :extension, :phone_type, :parsed_country_code,
        :attention, :address_line_1, :address_line_2, :address_line_3,
        :locality, :administrative_region, :postal_code, :country_code
      )
    end

    def lifecycle_params
      params.permit(:reason, :purpose, :authenticity_token)
    end

    def detail_params
      contact_params.except(:contact_kind, :label, :lock_version)
    end
  end
end
