module SupplierDirectoryAccess
  extend ActiveSupport::Concern

  private

  def require_supplier_directory_view!
    require_permission!(:view_supplier_directory)
  end

  def require_supplier_directory_management!
    require_permission!(:manage_supplier_directory)
  end

  def require_supplier_contact_details!
    raise ActiveRecord::RecordNotFound unless can_view_supplier_contact_details?
  end

  def supplier_directory
    Current.agency.suppliers
  end

  def set_supplier
    @supplier = supplier_directory.find(params[:supplier_id] || params[:id])
  end

  def set_supplier_location
    @supplier_location = @supplier.locations.find(params[:supplier_location_id])
  end

  def set_supplier_contact
    @supplier_contact = @supplier.contacts.find(params[:supplier_contact_id])
  end

  def can_view_supplier_contact_details?
    Current.agency_user.permitted?(:view_supplier_contact_details)
  end

  def rescue_supplier_directory_error(error, template)
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    record = form_error_record
    if record && error.code == :invalid
      attribute = supplier_form_error_attribute(error.message, record)
      record.errors.add(attribute, error.message)
    else
      flash.now[:alert] = error.message
    end
    render template, status: :unprocessable_entity
  end

  def form_error_record
    @contact_point || @supplier_location || @supplier_contact || @supplier
  end

  def supplier_form_error_attribute(message, record)
    case message
    when /at least one supplier category/i then :base
    when /other supplier category/i then :base
    when /email|address/i
      if record.respond_to?(:address)
        :address
      elsif record.respond_to?(:address_line_1) && message.match?(/line 1|address/i)
        :address_line_1
      else
        :base
      end
    when /phone|country/i
      if record.respond_to?(:number)
        :number
      elsif record.respond_to?(:phone_number)
        :phone_number
      else
        :base
      end
    when /website|url|hostname/i then record.respond_to?(:url) ? :url : :base
    when /line 1|postal|locality/i
      if record.respond_to?(:line_1)
        :line_1
      elsif record.respond_to?(:address_line_1)
        :address_line_1
      else
        :base
      end
    when /first name/i then record.respond_to?(:first_name) ? :first_name : :base
    when /last name/i then record.respond_to?(:last_name) ? :last_name : :base
    when /timezone/i then record.respond_to?(:timezone) ? :timezone : :base
    when /name/i then record.respond_to?(:name) ? :name : :base
    else :base
    end
  end

  def rescue_supplier_duplicate_review(error, template)
    @acknowledgement_token = error.token
    @duplicate_candidates = error.candidates
    flash.now[:alert] = error.message
    render template, status: :unprocessable_entity
  end

  def supplier_names_params
    params.expect(supplier: %i[display_name legal_name first_name last_name doing_business_as lock_version])
  end

  def supplier_kind_param
    params.expect(supplier: [ :kind ])[:kind]
  end

  def supplier_category_rows
    category_params = params.fetch(:supplier, ActionController::Parameters.new)
      .permit(category_codes: [], categories: [ :category_code, :other_label ])
    codes = Array(category_params[:category_codes])
    explicit_rows = category_rows_from(category_params[:categories])

    codes.map { |code| { category_code: code, other_label: other_category_label(explicit_rows, code) } }
  end

  def acknowledgement_params
    params.permit(:acknowledgement_token, :acknowledgement_reason)
  end

  def other_category_label(rows, code)
    return nil unless code == "other"

    row = rows.reverse.find { |entry| entry["category_code"] == "other" || entry[:category_code] == "other" }
    row&.fetch("other_label", nil) || row&.fetch(:other_label, nil)
  end

  def category_rows_from(value)
    case value
    when ActionController::Parameters
      value.values.map(&:to_h)
    when Hash
      value.values
    else
      Array(value)
    end.map { |row| row.respond_to?(:to_h) ? row.to_h : row }
  end
end
