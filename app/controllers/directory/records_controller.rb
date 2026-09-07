module Directory
  class RecordsController < ApplicationController
    def show
      @party = Current.agency.parties.find(params[:party_id])
    end
  end
end
