module DirectoryAccess
  extend ActiveSupport::Concern

  private

  def require_directory_view!
    require_permission!(:view_client_directory)
  end

  def require_directory_management!
    require_permission!(:manage_client_directory)
  end

  def directory_people
    Current.agency.client_people
  end

  def set_client_person
    @client_person = directory_people.find(params[:client_person_id] || params[:id])
  end

  def can_view_contact_details?
    Current.agency_user.permitted?(:view_client_contact_details)
  end

  def rescue_directory_error(error, template)
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    flash.now[:alert] = error.message
    render template, status: :unprocessable_entity
  end

  def rescue_duplicate_review(error, template)
    @acknowledgement_token = error.token
    @duplicate_candidates = error.candidates
    flash.now[:alert] = error.message
    render template, status: :unprocessable_entity
  end

  def person_params
    params.expect(client_person: %i[first_name middle_name last_name suffix preferred_name lock_version])
  end

  def acknowledgement_params
    params.permit(:acknowledgement_token, :acknowledgement_reason)
  end
end
