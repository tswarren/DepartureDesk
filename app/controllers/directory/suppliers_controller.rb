module Directory
  class SuppliersController < ApplicationController
    class_attribute :page_size, default: 50

    def index
      @status = SupplierProfile::STATUSES.include?(params[:status]) ? params[:status] : nil
      @party_kind = SupplierProfile::PARTY_KINDS.include?(params[:party_kind]) ? params[:party_kind] : nil
      @office_id = params[:office_id].presence
      @category_code = SupplierServiceCategoryAssignment::CATEGORY_CODES.include?(params[:category_code]) ? params[:category_code] : nil
      @page = [ params[:page].to_i, 1 ].max
      @today = DirectoryDate.today(Current.agency)
      @offices = Current.agency.offices.order(:name, :code, :id)

      scope = Current.agency.supplier_profiles
        .includes(
          :responsible_office,
          :service_category_assignments,
          party: [
            :person,
            :organization,
            { contact_point_purpose_assignments: { contact_point: [ :email_address, :phone_number, :postal_address ] } }
          ]
        )
        .joins(:party)
        .order("parties.sort_name", "parties.id")
      scope = scope.where(status: @status) if @status
      scope = scope.where(party_kind: @party_kind) if @party_kind
      scope = scope.where(responsible_office_id: @office_id) if @office_id
      if @category_code
        scope = scope.joins(:service_category_assignments).where(supplier_service_category_assignments: { category_code: @category_code })
      end
      Current.agency.offices.find(@office_id) if @office_id

      records = scope.offset((@page - 1) * page_size).limit(page_size + 1).to_a
      @has_next_page = records.size > page_size
      @supplier_profiles = records.first(page_size)
      @booking_contacts = primary_relationship_contacts(@supplier_profiles.map(&:party_id), "booking")
      @accounting_contacts = primary_relationship_contacts(@supplier_profiles.map(&:party_id), "accounting")
    end

    private

    def primary_relationship_contacts(party_ids, purpose)
      return {} if party_ids.empty?

      RelationshipPurposeAssignment
        .current_on(@today)
        .primary
        .where(organization_party_id: party_ids, purpose:)
        .includes(party_relationship: :origin_party)
        .each_with_object({}) do |assignment, mapping|
          next unless assignment.party_relationship.current_on?(@today)

          mapping[assignment.organization_party_id] ||= assignment.party_relationship.origin_party
        end
    end
  end
end
