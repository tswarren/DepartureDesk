module Directory
  class IdentifiersController < ApplicationController
    class_attribute :page_size, default: 50

    before_action :set_party

    def show
      @status = params[:status] == "deactivated" ? "deactivated" : "active"
      @page = [ params[:page].to_i, 1 ].max
      scope = @party.directory_external_identifiers.includes(:client_profile, :supplier_profile)

      if @status == "deactivated"
        records = history_scope(scope).order(:deactivated_at, :id).offset((@page - 1) * page_size).limit(page_size + 1).to_a
        @has_next_page = records.size > page_size
        @identifiers = records.first(page_size)
      else
        @identifiers = current_scope(scope).order(:identifier_type, :id).to_a
        @has_next_page = false
      end

      @eligible_types = eligible_types
    end

    private

    def set_party
      @party = Current.agency.parties.find(params[:party_id])
    end

    def current_scope(scope)
      scope.left_joins(:client_profile, :supplier_profile)
        .merge(ExternalIdentifier.current)
        .where(
          "(external_identifiers.party_id IS NOT NULL) OR (client_profiles.status = 'active') OR (supplier_profiles.status = 'active')"
        )
    end

    def history_scope(scope)
      scope.left_joins(:client_profile, :supplier_profile).where(
        "external_identifiers.status = 'inactive' OR client_profiles.status = 'inactive' OR supplier_profiles.status = 'inactive'"
      )
    end

    def eligible_types
      types = ExternalIdentifierRegistry.types_for_owner(:party)
      types += ExternalIdentifierRegistry.types_for_owner(:client_profile) if @party.client_profile&.active?
      types += ExternalIdentifierRegistry.types_for_owner(:supplier_profile) if @party.supplier_profile&.active?
      types
    end
  end
end
