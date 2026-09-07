module Directory
  class PartiesController < ApplicationController
    class_attribute :page_size, default: 50

    before_action :set_party, only: %i[show edit update deactivate reactivate]

    INDEX_ROLES = %w[client supplier].freeze

    def index
      @q = params[:q].to_s.strip.presence
      @party_kind = params[:party_kind] if Party::KINDS.include?(params[:party_kind])
      @role = params[:role] if INDEX_ROLES.include?(params[:role])
      @include_inactive = params[:include_inactive] == "1"
      @page = [ params[:page].to_i, 1 ].max
      scope = DirectoryPartySelector.new(
        agency: Current.agency,
        mode: @role || "any",
        q: @q,
        include_inactive: @include_inactive,
        party_kind: @party_kind
      ).relation.includes(:household, :organization, :client_profile, :supplier_profile, person: :agency_membership)
      records = scope.offset((@page - 1) * page_size).limit(page_size + 1).to_a
      @has_next_page = records.size > page_size
      @parties = records.first(page_size)
    end

    def show
      @today = DirectoryDate.today(Current.agency)
      @primary_assignments = @party.contact_point_purpose_assignments
        .current_eligible_primaries_on(@today)
        .includes(contact_point: [ :email_address, :phone_number, :postal_address ])
        .order(:contact_kind, :purpose, :id)
      @current_relationships = PartyRelationship.involving(@party)
        .includes(:origin_party, :related_party)
        .current_on(@today)
        .order(:effective_from, :id)
      @client_profile = @party.client_profile
      @supplier_profile = @party.supplier_profile
      @attention = PartyAttention.new(@party, date: @today)
      @overview_notes = @party.notes.visible_to(Current.agency_membership).active_records.pinned_first.limit(3)
      @overview_identifiers = @party.directory_external_identifiers.merge(ExternalIdentifier.current).order(:identifier_type, :id).limit(5)
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
        attributes: profile_params(@party_kind),
        create_anyway: party_params[:create_anyway],
        duplicate_override_reason: party_params[:duplicate_override_reason],
        acknowledged_candidate_ids: party_params[:acknowledged_candidate_ids],
        acknowledged_strength: party_params[:acknowledged_strength]
      ).call
      if result.status == :duplicate_review
        assign_new_form
        @duplicate_match = result.duplicate_match
        flash.now[:alert] = duplicate_review_message(@duplicate_match)
        render :new, status: :unprocessable_entity
        return
      end

      redirect_to directory_party_path(result.party), notice: "#{result.party.kind_label} created."
    rescue MembershipCommand::Error => error
      assign_new_form
      @duplicate_match = PartyDuplicateMatcher.new(
        agency: Current.agency,
        party_kind: @party_kind,
        attributes: profile_params(@party_kind)
      ).call
      @profile.validate
      flash.now[:alert] = error.message
      render :new, status: error.code == :stale ? :conflict : :unprocessable_entity
    end

    def edit
      @profile = @party.kind_profile
      @alternate_names = @party.alternate_names.visible.order(:name)
      @alternate_name = @party.alternate_names.new
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
      @alternate_names = @party.alternate_names.visible.order(:name)
      @alternate_name = @party.alternate_names.new
      flash.now[:alert] = error.message
      render :edit, status: error.code == :conflict ? :conflict : :unprocessable_entity
    end

    def deactivate
      DeactivateParty.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        reason: lifecycle_params[:reason],
        lock_version: lifecycle_params[:lock_version]
      ).call
      redirect_to directory_party_record_path(@party), notice: "Party deactivated."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_record_path(@party), alert: error.message
    end

    def reactivate
      ReactivateParty.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        reason: lifecycle_params[:reason],
        lock_version: lifecycle_params[:lock_version]
      ).call
      redirect_to directory_party_record_path(@party), notice: "Party reactivated."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_record_path(@party), alert: error.message
    end

    private

    def set_party
      @party = Current.agency.parties
        .includes(
          :organization,
          :household,
          { person: { agency_membership: :user } },
          { client_profile: :responsible_office },
          { supplier_profile: [ :responsible_office, :service_category_assignments ] }
        )
        .find(params[:id])
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
        :legal_name, :trading_name, :website,
        :create_anyway, :duplicate_override_reason, :acknowledged_strength,
        acknowledged_candidate_ids: []
      )
    end

    def assign_new_form
      @party = Current.agency.parties.new(party_kind: @party_kind, status: "active")
      @profile = profile_class(@party_kind).new(agency: Current.agency)
      @profile.assign_attributes(profile_params(@party_kind))
    end

    def duplicate_review_message(match)
      if match.strong?
        "A likely duplicate already exists. Review it before creating a separate identity."
      else
        "A similar directory record already exists."
      end
    end

    def directory_index_params
      {
        q: @q,
        party_kind: @party_kind,
        role: @role,
        include_inactive: (@include_inactive ? "1" : nil)
      }.compact_blank
    end
    helper_method :directory_index_params

    def profile_params(kind)
      allowed = CreateParty::PROFILE_ATTRS[kind] || []
      party_params.slice(*allowed.map(&:to_s))
    end

    def profile_lock_version_param
      party_params[:profile_lock_version]
    end

    def lifecycle_params
      params.permit(:reason, :lock_version)
    end
  end
end
