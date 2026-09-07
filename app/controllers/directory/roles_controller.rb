module Directory
  class RolesController < ApplicationController
    def show
      @party = Current.agency.parties
        .includes(
          client_profile: [ :responsible_office, :primary_advisor_membership ],
          supplier_profile: [ :responsible_office, :service_category_assignments ]
        )
        .find(params[:party_id])
      @client_profile = @party.client_profile
      @supplier_profile = @party.supplier_profile
      @active_offices = Current.agency.offices.active.order(:name, :code, :id)
      @advisor_memberships = Current.agency.agency_memberships.active
        .joins(person_party: :party)
        .includes(person_party: :party)
        .order("parties.sort_name", "agency_memberships.id")
    end
  end
end
