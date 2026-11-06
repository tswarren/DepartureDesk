# Adds or edits a supplier's payee account (SUP-02). Audited against the
# supplier.
class SavePayeeAccount < AgencyCommand
  ATTRIBUTES = %w[name currency payment_instructions].freeze

  def initialize(agency:, actor:, supplier:, attributes:, payee_account: nil, lock_version: nil)
    @agency = agency
    @actor = actor
    @supplier = supplier
    @payee_account = payee_account
    @attributes = attributes.to_h.stringify_keys.slice(*ATTRIBUTES)
    @lock_version = lock_version
  end

  def call
    ensure_directory_actor!(@actor, @agency, :manage_supplier_directory)
    ensure_active_agency!(@agency)

    ActiveRecord::Base.transaction do
      @agency.lock!
      supplier = @agency.suppliers.lock.find(@supplier.id)
      account = if @payee_account
        supplier.payee_accounts.lock.find(@payee_account.id).tap do |existing|
          raise Error.new("This payee account was updated by someone else.", code: :conflict) if @lock_version.blank? || existing.lock_version != @lock_version.to_i
        end
      else
        raise Error.new("That supplier is not active.", code: :invalid_state) unless supplier.active?
        supplier.payee_accounts.new(agency: @agency)
      end
      creating = account.new_record?
      account.assign_attributes(@attributes)
      changed = account.changed - %w[lock_version updated_at]
      return Result.new(status: :noop, record: account) if !creating && changed.empty?

      account.save!
      audit!(
        agency: @agency,
        action: creating ? "supplier.payee_account_added" : "supplier.payee_account_updated",
        subject: supplier,
        actor: @actor,
        details: { "supplier_id" => supplier.id, "payee_account_id" => account.id, "changed" => changed.sort }
      )
      Result.new(status: creating ? :created : :updated, record: account)
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  rescue ActiveRecord::RecordNotUnique
    raise Error.new("That payee account name is already used for this supplier.", code: :invalid)
  end
end
