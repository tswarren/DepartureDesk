module Directory
  class NotesController < ApplicationController
    class_attribute :page_size, default: 50

    before_action :set_party

    def show
      @page = [ params[:page].to_i, 1 ].max
      visible = @party.notes.visible_to(Current.agency_membership)
      @notes = visible.active_records.pinned_first
      records = visible.historical_records.order(created_at: :desc, id: :desc)
        .offset((@page - 1) * page_size).limit(page_size + 1).to_a
      @has_next_page = records.size > page_size
      @historical_notes = records.first(page_size)
      @note = @party.notes.new(visibility: "standard")
    end

    private

    def set_party
      @party = Current.agency.parties.find(params[:party_id])
    end
  end
end
