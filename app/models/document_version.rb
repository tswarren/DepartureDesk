# One issued client document (DOC-01, DOC-11; ADR 0019): a confirmation or
# invoice of a booking, or a receipt's PDF, rendered once at issue. It keeps
# the PDF, its SHA-256 and a snapshot of exactly the values it shows, and
# never changes. A reissue (DOC-12) is a new row that supersedes it, from
# Slice 1b.
class DocumentVersion < ApplicationRecord
  TYPES = %w[confirmation invoice receipt].freeze
  TYPE_LABELS = { "confirmation" => "Booking confirmation", "invoice" => "Invoice", "receipt" => "Receipt" }.freeze
  # The reference namespace each type numbers from (REF-05). A receipt's PDF
  # keeps the number its receipt was issued with.
  NAMESPACES = { "confirmation" => ReferenceSequence::CONFIRMATION_NAMESPACE, "invoice" => ReferenceSequence::INVOICE_NAMESPACE }.freeze

  belongs_to :agency
  belongs_to :client_booking, optional: true, inverse_of: :document_versions
  belongs_to :receipt, optional: true, inverse_of: :document_versions
  belongs_to :issued_by, class_name: "AgencyUser"
  belongs_to :supersedes, class_name: "DocumentVersion", optional: true
  has_many :deliveries, -> { order(:delivered_on, :recorded_at) }, class_name: "DocumentDelivery", inverse_of: :document_version, dependent: :restrict_with_exception
  has_one_attached :pdf

  enum :document_type, TYPES.index_by(&:itself), validate: true, prefix: :type

  before_update { raise ActiveRecord::ReadOnlyRecord if (changed - %w[updated_at]).any? }
  before_destroy { raise ActiveRecord::ReadOnlyRecord }

  def label = TYPE_LABELS.fetch(document_type)

  # REF-05: a reissued version shows a version suffix; the first shows none.
  def display_number = version_number == 1 ? number : "#{number}-v#{version_number}"

  def filename = "#{display_number}.pdf"
end
