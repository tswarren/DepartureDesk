module Directory
  class SupplierProfilesController < ApplicationController
    before_action :set_party
    before_action :set_profile, only: %i[update deactivate reactivate assign_category remove_category]

    def create
      CreateSupplierProfile.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        office: office_from_params!
      ).call
      redirect_to directory_party_path(@party), notice: "Supplier role added."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_path(@party), alert: error.message
    end

    def update
      UpdateSupplierProfile.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        profile: @profile,
        office: office_from_params!,
        default_currency: profile_params[:default_currency],
        portal_url: profile_params[:portal_url],
        payment_term_notes: profile_params[:payment_term_notes],
        commission_notes: profile_params[:commission_notes],
        booking_instructions: profile_params[:booking_instructions],
        payment_instructions: profile_params[:payment_instructions],
        cancellation_policy_notes: profile_params[:cancellation_policy_notes],
        lock_version: profile_params[:lock_version]
      ).call
      redirect_to directory_party_path(@party), notice: "Supplier role updated."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_path(@party), alert: error.message
    end

    def deactivate
      DeactivateSupplierProfile.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        profile: @profile,
        reason: profile_params[:reason],
        lock_version: profile_params[:lock_version]
      ).call
      redirect_to directory_party_path(@party), notice: "Supplier role deactivated."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_path(@party), alert: error.message
    end

    def reactivate
      ReactivateSupplierProfile.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        profile: @profile,
        office: office_from_params!,
        lock_version: profile_params[:lock_version]
      ).call
      redirect_to directory_party_path(@party), notice: "Supplier role reactivated."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_path(@party), alert: error.message
    end

    def assign_category
      AssignSupplierServiceCategory.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        profile: @profile,
        category_code: profile_params[:category_code]
      ).call
      redirect_to directory_party_path(@party), notice: "Supplier category added."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_path(@party), alert: error.message
    end

    def remove_category
      RemoveSupplierServiceCategory.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        profile: @profile,
        category_code: profile_params[:category_code]
      ).call
      redirect_to directory_party_path(@party), notice: "Supplier category removed."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_path(@party), alert: error.message
    end

    private

    def set_party
      @party = Current.agency.parties.find(params[:party_id])
    end

    def set_profile
      @profile = @party.supplier_profile
      raise ActiveRecord::RecordNotFound unless @profile
    end

    def profile_params
      params.fetch(:supplier_profile, params).permit(
        :responsible_office_id,
        :default_currency,
        :portal_url,
        :payment_term_notes,
        :commission_notes,
        :booking_instructions,
        :payment_instructions,
        :cancellation_policy_notes,
        :category_code,
        :lock_version,
        :reason,
        :status
      )
    end

    def office_from_params!
      office_id = profile_params[:responsible_office_id]
      raise MembershipCommand::Error.new("Choose an active office.", code: :invalid) if office_id.blank?

      Current.agency.offices.find(office_id)
    end
  end
end
