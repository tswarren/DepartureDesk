class ClientOrganizationWebsitesController < ClientOrganizationContactPointsController
  private

  def contact_scope
    @client_organization.websites
  end

  def create_command
    CreateClientOrganizationWebsite
  end

  def update_command
    UpdateClientOrganizationWebsite
  end

  def status_command
    ChangeClientOrganizationWebsiteStatus
  end

  def set_primary_command
    SetPreferredClientOrganizationWebsite
  end

  def channel_label
    "Website"
  end

  def contact_params
    params.expect(client_organization_website: %i[url label preferred lock_version])
  end
end
