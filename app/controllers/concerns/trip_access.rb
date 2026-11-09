# Travelers and Client Trips (S-22 to S-24). Every staff user may view and
# manage them (ACC-30): travelers through the client directory actions,
# trips through the booking actions. A command error that starts with a
# field's label is shown on that field.
module TripAccess
  extend ActiveSupport::Concern

  included { helper_method :client_profile_path_for }

  private

  def form_params(scope, fields)
    params.fetch(scope, {}).permit(*fields).to_h
  end

  def client_profile_path_for(client, **options)
    client.client_person ? client_person_path(client.client_person, **options) : client_organization_path(client.client_organization, **options)
  end
end
