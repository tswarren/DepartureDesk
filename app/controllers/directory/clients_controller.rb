module Directory
  class ClientsController < ApplicationController
    class_attribute :page_size, default: 50

    def index
      @status = ClientProfile::STATUSES.include?(params[:status]) ? params[:status] : nil
      @party_kind = Party::KINDS.include?(params[:party_kind]) ? params[:party_kind] : nil
      @office_id = params[:office_id].presence
      @advisor_id = params[:advisor_id].presence
      @page = [ params[:page].to_i, 1 ].max
      @today = DirectoryDate.today(Current.agency)
      @offices = Current.agency.offices.order(:name, :code, :id)
      @advisors = Current.agency.agency_memberships.active
        .joins(person_party: :party)
        .includes(person_party: :party)
        .order("parties.sort_name", "agency_memberships.id")

      scope = Current.agency.client_profiles
        .includes(
          :responsible_office,
          { primary_advisor_membership: { person_party: :party } },
          party: [ :person, :household, :organization, { contact_point_purpose_assignments: { contact_point: [ :email_address, :phone_number, :postal_address ] } } ]
        )
        .joins(:party)
        .order("parties.sort_name", "parties.id")
      scope = scope.where(status: @status) if @status
      scope = scope.where(party_kind: @party_kind) if @party_kind
      scope = scope.where(responsible_office_id: @office_id) if @office_id
      scope = scope.where(primary_advisor_membership_id: @advisor_id) if @advisor_id
      Current.agency.offices.find(@office_id) if @office_id
      Current.agency.agency_memberships.find(@advisor_id) if @advisor_id

      records = scope.offset((@page - 1) * page_size).limit(page_size + 1).to_a
      @has_next_page = records.size > page_size
      @client_profiles = records.first(page_size)
    end
  end
end
