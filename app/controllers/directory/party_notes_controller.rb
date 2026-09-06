module Directory
  class PartyNotesController < ApplicationController
    before_action :set_party
    before_action :set_note, only: %i[correct remove pin unpin]

    def create
      CreatePartyNote.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        body: note_params[:body],
        visibility: note_params[:visibility].presence || "standard",
        pinned: note_params[:pinned] == "1"
      ).call
      redirect_to directory_party_notes_path(@party), notice: "Note added."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_notes_path(@party), alert: error.message
    end

    def correct
      CorrectPartyNote.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        note: @note,
        body: note_params[:body],
        reason: note_params[:reason]
      ).call
      redirect_to directory_party_notes_path(@party), notice: "Note corrected."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_notes_path(@party), alert: error.message
    end

    def remove
      RemovePartyNote.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        note: @note,
        reason: note_params[:reason]
      ).call
      redirect_to directory_party_notes_path(@party), notice: "Note removed."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_notes_path(@party), alert: error.message
    end

    def pin
      SetPartyNotePinned.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        note: @note,
        pinned: true
      ).call
      redirect_to directory_party_notes_path(@party), notice: "Note pinned."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_notes_path(@party), alert: error.message
    end

    def unpin
      SetPartyNotePinned.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        note: @note,
        pinned: false
      ).call
      redirect_to directory_party_notes_path(@party), notice: "Note unpinned."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_notes_path(@party), alert: error.message
    end

    private

    def set_party
      @party = Current.agency.parties.find(params[:party_id])
    end

    def set_note
      @note = @party.notes.visible_to(Current.agency_membership).active_records.find(params[:id])
    end

    def note_params
      params.fetch(:party_note, params).permit(:body, :visibility, :pinned, :reason)
    end
  end
end
