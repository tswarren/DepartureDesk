# Authorizes a reseller relationship, or changes its name or direct-contact
# setting (ACC-13, DOC-08; step 9 plan question 3). Authorizing one never
# assigns it a booking (ACC-13). Pause, suspension and ending are not built
# in Slice 1, so a new relationship is Active and stays so.
class SaveReseller < AgencyCommand
  include DepartureCommandSupport

  def initialize(agency:, actor:, attributes:, reseller: nil, lock_version: nil)
    @agency = agency
    @actor = actor
    @attributes = attributes.to_h.symbolize_keys
    @reseller = reseller
    @lock_version = lock_version
  end

  def call
    ensure_departure_actor!(:manage_reseller_relationships)

    ActiveRecord::Base.transaction do
      lock_authorized_agency!(:manage_reseller_relationships)
      reseller = if @reseller
        @agency.resellers.lock.find(@reseller.id).tap { |record| ensure_current_lock_version!(record) }
      else
        @agency.resellers.new
      end
      creating = reseller.new_record?
      reseller.name = @attributes[:name] if creating || @attributes.key?(:name)
      reseller.direct_contact_allowed = ActiveModel::Type::Boolean.new.cast(@attributes[:direct_contact_allowed]) if @attributes.key?(:direct_contact_allowed)
      return Result.new(status: :noop, record: reseller) unless creating || reseller.changed?

      changed = reseller.changed - %w[updated_at lock_version]
      reseller.save!
      audit!(agency: @agency, action: creating ? "reseller.authorized" : "reseller.updated", subject: reseller, actor: @actor,
        details: { "reseller_id" => reseller.id, "name" => reseller.name, "direct_contact_allowed" => reseller.direct_contact_allowed,
                   "changed_fields" => (changed unless creating) }.compact)
      Result.new(status: creating ? :created : :updated, record: reseller)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
