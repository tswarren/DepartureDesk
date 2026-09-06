module Directory
  class PartiesController < ApplicationController
    class_attribute :page_size, default: 50

    before_action :set_party, only: %i[show edit update]

    def index
      @party_kind = params[:party_kind] if Party::KINDS.include?(params[:party_kind])
      @page = [ params[:page].to_i, 1 ].max
      scope = Current.agency.parties
        .includes(:household, :organization, person: :agency_membership)
        .order(:sort_name, :id)
      scope = scope.where(party_kind: @party_kind) if @party_kind
      records = scope.offset((@page - 1) * page_size).limit(page_size + 1).to_a
      @has_next_page = records.size > page_size
      @parties = records.first(page_size)
    end

    def show
      @alternate_names = @party.alternate_names.visible.order(:name)
      @alternate_name = @party.alternate_names.new
      @today = DirectoryDate.today(Current.agency)
      @primary_assignments = @party.contact_point_purpose_assignments
        .current_eligible_primaries_on(@today)
        .includes(contact_point: [ :email_address, :phone_number, :postal_address ])
        .order(:contact_kind, :purpose, :id)
      @current_relationships = PartyRelationship.involving(@party)
        .includes(:origin_party, :related_party)
        .current_on(@today)
        .order(:effective_from, :id)
    end

    def new
      @party_kind = params[:party_kind].presence
      return unless Party::KINDS.include?(@party_kind)

      @party = Current.agency.parties.new(party_kind: @party_kind, status: "active")
      @profile = profile_class(@party_kind).new(agency: Current.agency)
    end

    def create
      @party_kind = party_params[:party_kind].to_s
      unless Party::KINDS.include?(@party_kind)
        flash.now[:alert] = "Choose a person, household, or organization."
        render :new, status: :unprocessable_entity
        return
      end

      result = CreateParty.new(
        agency: Current.agency,
        actor: Current.user,
        party_kind: @party_kind,
        attributes: profile_params(@party_kind)
      ).call
      redirect_to directory_party_path(result.party), notice: "#{result.party.kind_label} created."
    rescue MembershipCommand::Error => error
      @party = Current.agency.parties.new(party_kind: @party_kind, status: "active")
      @profile = profile_class(@party_kind).new(agency: Current.agency)
      @profile.assign_attributes(profile_params(@party_kind))
      @profile.validate
      flash.now[:alert] = error.message
      render :new, status: :unprocessable_entity
    end

    def edit
      @profile = @party.kind_profile
    end

    def update
      UpdateParty.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        attributes: profile_params(@party.party_kind),
        party_lock_version: party_params[:lock_version],
        profile_lock_version: profile_lock_version_param
      ).call
      redirect_to directory_party_path(@party), notice: "#{@party.kind_label} updated."
    rescue MembershipCommand::Error => error
      @profile = @party.kind_profile
      @profile.assign_attributes(profile_params(@party.party_kind))
      @profile.validate
      flash.now[:alert] = error.message
      render :edit, status: error.code == :conflict ? :conflict : :unprocessable_entity
    end

    private

    def set_party
      @party = Current.agency.parties.find(params[:id])
    end

    def profile_class(kind)
      { "person" => Person, "household" => Household, "organization" => Organization }.fetch(kind)
    end

    def party_params
      params.fetch(:party, {}).permit(
        :party_kind, :lock_version, :profile_lock_version, :agency_id,
        :given_name, :middle_name, :family_name, :prefix, :suffix, :preferred_name,
        :form_of_address, :pronouns, :date_of_birth,
        :name, :correspondence_name,
        :legal_name, :trading_name, :website
      )
    end

    def profile_params(kind)
      allowed = CreateParty::PROFILE_ATTRS[kind] || []
      party_params.slice(*allowed.map(&:to_s))
    end

    def profile_lock_version_param
      party_params[:profile_lock_version]
    end
  end
end
