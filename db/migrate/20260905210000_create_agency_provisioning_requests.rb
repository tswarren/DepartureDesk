class CreateAgencyProvisioningRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :agency_provisioning_requests,
      id: :uuid,
      default: -> { "uuidv7()" } do |table|
      table.string :idempotency_key_digest, null: false
      table.string :intent_digest, null: false
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.datetime :created_at, null: false
    end

    add_index :agency_provisioning_requests,
      :idempotency_key_digest,
      unique: true,
      name: "index_agency_provisioning_requests_on_idempotency_key_digest"

    add_index :agency_provisioning_requests,
      :intent_digest,
      unique: true,
      name: "index_agency_provisioning_requests_on_intent_digest"
  end
end
