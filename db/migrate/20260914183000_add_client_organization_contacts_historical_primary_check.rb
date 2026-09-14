class AddClientOrganizationContactsHistoricalPrimaryCheck < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :client_organization_contacts,
      "ends_on IS NULL OR NOT \"primary\"",
      name: "client_org_contacts_primary_requires_current"
  end
end
