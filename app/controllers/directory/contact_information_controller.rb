module Directory
  class ContactInformationController < ApplicationController
    class_attribute :page_size, default: 50

    before_action :set_party

    def show
      @status = params[:status] == "deactivated" ? "deactivated" : "active"
      @page = [ params[:page].to_i, 1 ].max
      @today = DirectoryDate.today(Current.agency)
      scope = @party.contact_points.includes(:email_address, :phone_number, :postal_address, :purpose_assignments)

      if @status == "deactivated"
        records = scope.history.order(:deactivated_at, :id).offset((@page - 1) * page_size).limit(page_size + 1).to_a
        @has_next_page = records.size > page_size
        @contact_points = records.first(page_size)
      else
        @contact_points = scope.current.order(:contact_kind, :id).to_a
        @has_next_page = false
      end

      @emails = @contact_points.select(&:email?)
      @phones = @contact_points.select(&:phone?)
      @addresses = @contact_points.select(&:postal_address?)
    end

    private

    def set_party
      @party = Current.agency.parties.find(params[:party_id])
    end
  end
end
