require "test_helper"

# Supplier documents on an arrangement (SUP-06, S-12, ADR 0019 amendment).
class ArrangementDocumentsTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @departure = CreateDeparture.new(agency: @agency, actor: @admin, attributes: { name: "Docs", operating_currency: "USD" }).call.record
    supplier = CreateSupplier.new(agency: @agency, actor: @admin, kind: "organization", names: { display_name: "Doc Supplier" }, categories: [ "lodging" ]).call.record
    @arrangement = CreateSupplierArrangement.new(agency: @agency, actor: @admin, departure: @departure, supplier_id: supplier.id).call.record
  end

  test "each accepted type uploads, and downloads match the stored SHA-256" do
    sign_in_as @admin
    { "confirmation.pdf" => [ "application/pdf", "inline" ], "logo.png" => [ "image/png", "inline" ],
      "agreement.docx" => [ "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "attachment" ],
      "rates.xlsx" => [ "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "attachment" ] }.each do |file, (type, disposition)|
      upload!(file)
      document = @arrangement.documents.find_by!(sha256: Digest::SHA256.file(file_fixture(file)).hexdigest)
      assert_equal type, document.file.content_type

      get departure_arrangement_document_path(@departure, @arrangement, document)
      assert_response :success, file
      assert_equal File.binread(file_fixture(file)), response.body
      assert response.headers["Content-Disposition"].start_with?(disposition), "#{file}: #{response.headers["Content-Disposition"]}"
      assert_match(/sandbox/, response.headers["Content-Security-Policy"])
    end
    assert_equal 4, AuditEvent.where(subject_id: @arrangement.id, action: "supplier_arrangement.document_added").count
  end

  test "a macro-enabled Office file, a renamed archive and a renamed script are refused" do
    sign_in_as @admin
    upload!("macro.docm", name: "innocent.docx")
    assert_response :unprocessable_entity
    assert_select "#form-error-summary a[href='#arrangement_document_file']", text: /macros/
    assert_select "#arrangement_document_file_error", text: /macros/
    upload!("archive.zip", name: "agreement.docx")
    assert_select "#form-error-summary", text: /PDF, PNG, JPEG, Word/
    upload!("not_an_image.png")
    assert_select "#form-error-summary", text: /PDF, PNG, JPEG, Word/
    assert_empty @arrangement.documents
  end

  test "a file over 20 MB is refused" do
    large = Tempfile.new([ "large", ".pdf" ], binmode: true)
    large.write(File.binread(file_fixture("confirmation.pdf")) + ("\0" * (ArrangementDocument::MAX_BYTES + 1)))
    large.rewind
    error = assert_raises(AgencyCommand::Error) do
      UploadArrangementDocument.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement,
        upload: Rack::Test::UploadedFile.new(large.path, "application/pdf"), kind: "quote").call
    end
    assert_match(/20 MB/, error.message)
  ensure
    large&.close!
  end

  test "removal is allowed at any time, audited, and purges the file" do
    sign_in_as @admin
    upload!("confirmation.pdf")
    document = @arrangement.documents.sole
    blob_id = document.file.blob.id

    perform_enqueued_jobs do
      delete departure_arrangement_document_path(@departure, @arrangement, document)
    end
    assert_redirected_to departure_arrangement_documents_path(@departure, @arrangement)
    assert_empty @arrangement.documents.reload
    assert_not ActiveStorage::Blob.exists?(blob_id)
    event = AuditEvent.where(subject_id: @arrangement.id, action: "supplier_arrangement.document_removed").sole
    assert_equal "confirmation.pdf", event.details["filename"]
    assert_equal document.sha256, event.details["sha256"]
  end

  test "staff without an ACC-31 permission can't see or download documents, and only Supplier arrangements can upload" do
    sign_in_as @admin
    upload!("confirmation.pdf")
    document = @arrangement.documents.sole

    sign_in_as agency_users(:harbor_baseline_staff)
    get departure_arrangement_path(@departure, @arrangement)
    assert_select "nav[aria-label='Arrangement sections'] a", text: "Documents", count: 0
    get departure_arrangement_documents_path(@departure, @arrangement)
    assert_redirected_to root_path
    get departure_arrangement_document_path(@departure, @arrangement, document)
    assert_redirected_to root_path

    sign_in_as agency_users(:harbor_staff) # Departure management: may view, may not upload
    get departure_arrangement_document_path(@departure, @arrangement, document)
    assert_response :success
    upload!("logo.png")
    assert_redirected_to root_path
    assert_equal 1, @arrangement.documents.count
  end

  test "another agency's arrangement document is not found" do
    sign_in_as @admin
    upload!("confirmation.pdf")
    document = @arrangement.documents.sole
    sign_in_as agency_users(:cove_admin)
    get departure_arrangement_document_path(@departure, @arrangement, document)
    assert_response :not_found
  end

  private

  def upload!(file, name: file)
    type = { "pdf" => "application/pdf", "png" => "image/png", "docx" => "application/octet-stream", "xlsx" => "application/octet-stream" }.fetch(File.extname(name).delete("."), "application/octet-stream")
    upload = Rack::Test::UploadedFile.new(file_fixture(file).to_s, type, original_filename: name)
    post departure_arrangement_documents_path(@departure, @arrangement), params: { arrangement_document: { file: upload, kind: "agreement" } }
  end
end
