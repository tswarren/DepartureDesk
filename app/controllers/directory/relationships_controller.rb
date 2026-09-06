module Directory
  class RelationshipsController < ApplicationController
    class_attribute :page_size, default: 50

    before_action :set_party

    def show
      @today = DirectoryDate.today(Current.agency)
      @page = [ params[:page].to_i, 1 ].max
      scope = PartyRelationship.involving(@party)
        .includes(:origin_party, :related_party, :purpose_assignments)
      @current_relationships = scope.record_valid
        .where("effective_until IS NULL OR effective_until > ?", @today)
        .order(:effective_from, :id)
      records = scope.historical_on(@today).order(:effective_until, :id).offset((@page - 1) * page_size).limit(page_size + 1).to_a
      @has_next_page = records.size > page_size
      @historical_relationships = records.first(page_size)
    end

    private

    def set_party
      @party = Current.agency.parties.find(params[:party_id])
    end
  end
end
