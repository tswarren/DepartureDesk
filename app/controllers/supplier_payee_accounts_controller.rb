class SupplierPayeeAccountsController < ApplicationController
  include SupplierDirectoryAccess

  ERROR_FIELDS = [ [ :name, /name/i ], [ :currency, /currency/i ], [ :payment_instructions, /instructions/i ] ].freeze

  before_action :require_supplier_directory_view!
  before_action :require_supplier_directory_management!
  before_action :set_supplier
  before_action :set_payee_account, only: %i[edit update]

  def new
    @payee_account = @supplier.payee_accounts.new(currency: Current.agency.default_currency)
  end

  def create
    SavePayeeAccount.new(agency: Current.agency, actor: Current.agency_user, supplier: @supplier, attributes: payee_account_params).call
    redirect_to supplier_path(@supplier, anchor: "payee-accounts"), notice: "Payee account saved."
  rescue AgencyCommand::Error => error
    @payee_account = @supplier.payee_accounts.new(payee_account_params.except(:lock_version))
    render_form_error(error, @payee_account, :new, ERROR_FIELDS)
  end

  def edit
  end

  def update
    SavePayeeAccount.new(
      agency: Current.agency, actor: Current.agency_user, supplier: @supplier, payee_account: @payee_account,
      attributes: payee_account_params.except(:lock_version), lock_version: payee_account_params[:lock_version]
    ).call
    redirect_to supplier_path(@supplier, anchor: "payee-accounts"), notice: "Payee account saved."
  rescue AgencyCommand::Error => error
    @payee_account.assign_attributes(payee_account_params.except(:lock_version))
    render_form_error(error, @payee_account, :edit, ERROR_FIELDS)
  end

  private

  def set_payee_account
    @payee_account = @supplier.payee_accounts.find(params[:id])
  end

  def payee_account_params
    params.require(:payee_account).permit(:name, :currency, :payment_instructions, :lock_version)
  end
end
