# The values an issued document shows, built once from recorded data
# (DOC-03, DOC-11; step 10 plan, questions 4, 5 and 13). The template
# renders only from this snapshot, which is stored with the PDF, so what is
# kept is exactly what was shown, and later changes to the agency profile,
# footers or records never reach an issued document.
#
# This is the only code that reads records for a document. It never copies
# a date of birth, passport detail, supplier reference, emergency contact,
# supplier cost, commission or margin (DOC-03, CLT-36, CMN-53).
class DocumentSnapshot
  FAMILIES = { "confirmation" => "confirmation", "invoice" => "invoice", "receipt" => "receipt" }.freeze

  def self.build(document_type:, number:, agency:, issued_at:, booking: nil, receipt: nil)
    new(document_type:, number:, agency:, issued_at:, booking:, receipt:).build
  end

  def initialize(document_type:, number:, agency:, issued_at:, booking:, receipt:)
    @type = document_type
    @number = number
    @agency = agency
    @issued_at = issued_at
    @booking = booking
    @receipt = receipt
  end

  def build
    base = {
      "document_type" => @type, "title" => DocumentVersion::TYPE_LABELS.fetch(@type), "number" => @number,
      "issued_on" => date(@issued_at.in_time_zone(@agency.default_timezone).to_date),
      "agency" => agency_block, "footer_markdown" => footer, "logo_checksum" => (@agency.logo.blob.checksum if @agency.logo.attached?)
    }
    base.merge(send(:"#{@type}_values"))
  end

  private

  def confirmation_values
    booking = @booking
    selections = booking.choice_selections.sort_by { |selection| [ selection.option.choice.position, selection.option.position, selection.unit_number.to_i ] }
    names = booking.booking_travelers.index_by(&:id).transform_values(&:display_name)
    booking_values.merge(
      "travelers" => booking.booking_travelers.map(&:display_name),
      "services" => selections.map do |selection|
        { "label" => selection.label, "travelers" => selection.occupants.filter_map { |occupant| names[occupant.booking_traveler_id] } }
      end,
      "total" => money(booking.client_charge.total_minor_units),
      "client_terms" => "Version #{booking.client_charge.client_terms_version.version_number}",
      "confirmed_on" => date(booking.confirmed_at.in_time_zone(@agency.default_timezone).to_date)
    )
  end

  def invoice_values
    booking = @booking
    charge = booking.client_charge
    names = booking.booking_travelers.index_by(&:id).transform_values(&:display_name)
    installments = charge.installments.to_a
    payments = installments.flat_map { |installment| installment.applications.map { |application| [ application, installment ] } }
      .group_by { |application, _| application.client_payment }
      .sort_by { |payment, _| [ payment.paid_on, payment.payment_reference ] }
      .filter_map do |payment, rows|
        amount = rows.sum { |application, _| application.amount_minor_units }
        next if amount.zero?

        { "reference" => payment.payment_reference, "paid_on" => date(payment.paid_on), "amount" => money(amount),
          "paid_to" => payment.agency_route? ? @agency.name : payment.supplier.display_name_for_directory }
      end
    booking_values.merge(
      "lines" => charge.lines.sort_by { |line| [ line.created_at, line.id ] }.map do |line|
        { "description" => line.description, "traveler" => names[line.booking_traveler_id], "amount" => money(line.amount_minor_units) }
      end,
      "total" => money(charge.total_minor_units),
      "installments" => installments.map do |installment|
        { "description" => installment.description, "due_on" => date(installment.due_on), "amount" => money(installment.amount_minor_units),
          "paid" => money(installment.paid_minor_units), "open" => money([ installment.open_minor_units, 0 ].max) }
      end,
      "payments" => payments,
      "paid" => money(charge.paid_minor_units),
      "still_due" => money(charge.remainder_minor_units)
    )
  end

  # CMN-55: what the receipt record holds, as issued.
  def receipt_values
    receipt = @receipt
    payment = receipt.client_payment
    {
      "recipient" => receipt.payer_name, "departure" => receipt.departure.name,
      "amount" => Money.new(receipt.amount_minor_units, receipt.currency).format, "paid_on" => date(receipt.paid_on),
      "collected_by" => "#{@agency.name}, directly", "method" => [ ClientPayment::METHOD_LABELS.fetch(receipt.payment_method), receipt.reference ].compact.join(" · "),
      "payment_reference" => payment.payment_reference,
      "applied" => receipt.applied.map do |row|
        { "booking_reference" => row["booking_reference"], "installment" => row["installment"], "due_on" => date(Date.iso8601(row["due_on"])),
          "amount" => Money.new(row["amount_minor_units"], receipt.currency).format }
      end
    }
  end

  # D-100, DOC-09: a booking a reseller owns at issue says so.
  def booking_values
    trip = @booking.client_trip
    departure = trip.departure
    {
      "recipient" => trip.client.source.display_name, "booking_reference" => @booking.booking_reference, "trip_reference" => trip.trip_reference,
      "booked_through" => @booking.owner_reseller&.name, "offering" => @booking.offering.name,
      "departure" => departure&.name, "dates" => departure && [ departure.starts_on, departure.ends_on ].compact.map { |day| date(day) }.join(" to ")
    }
  end

  # SET-04 to SET-06: the profile fields this family's flags include, when set.
  def agency_block
    flags = @agency.document_inclusions.find { |row| row.document_family == FAMILIES.fetch(@type) }
    include = ->(field) { flags.nil? || flags.includes?(field) }
    address = [ @agency.address_line_1, @agency.address_line_2,
                [ @agency.address_locality, @agency.address_region, @agency.address_postal_code ].compact_blank.join(" "), @agency.address_country_code ].compact_blank
    phone = @agency.phone_normalized_number.presence &&
      PhoneNumberNormalizer.display(normalized_number: @agency.phone_normalized_number, country_code: @agency.phone_country_code, extension: @agency.phone_extension)
    {
      "display_name" => (@agency.name if include.("display_name")),
      "legal_name" => (@agency.legal_name.presence if include.("legal_name")),
      "contact_email" => (@agency.contact_email.presence if include.("contact_email")),
      "phone" => (phone if include.("phone")),
      "mailing_address" => (address if include.("mailing_address") && @agency.address_line_1.present?),
      "contact_name" => (@agency.agency_contact_name.presence if include.("agency_contact_name")),
      "seller_of_travel_disclosure" => (@agency.seller_of_travel_disclosure.presence if include.("seller_of_travel_disclosure"))
    }.compact
  end

  # SET-07: the confirmation footer, or the financial-document footer.
  def footer
    flags = @agency.document_inclusions.find { |row| row.document_family == FAMILIES.fetch(@type) }
    return if flags && !flags.includes?("footer")

    (@type == "confirmation" ? @agency.confirmation_footer : @agency.financial_document_footer).presence
  end

  def money(minor_units) = Money.new(minor_units, @booking.currency).format

  def date(day) = day.strftime("%B %-d, %Y")
end
