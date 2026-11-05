require "test_helper"

# REF-02, REF-03, REF-05, D-84, D-89.
class ReferenceSequenceTest < ActiveSupport::TestCase
  include ReferenceIssuance

  EXPECTED_FIRST = {
    "client" => "CL-000001",
    "supplier" => "SUP-000001",
    "departure" => "DEP-0001",
    "trip" => "T-00001",
    "client_payment" => "PAY-00001",
    "arrangement" => "ARR-0001",
    "supplier_payment" => "SPY-0001",
    "confirmation" => "CNF-00001",
    "invoice" => "INV-00001",
    "receipt" => "RCP-00001"
  }.freeze

  setup do
    @agency = agencies(:harbor)
  end

  test "every namespace issues its prefix at its minimum width" do
    assert_equal EXPECTED_FIRST.keys.sort, ReferenceSequence::NAMESPACES.sort
    EXPECTED_FIRST.each do |namespace, reference|
      issued = ReferenceSequence.transaction { issue_reference!(@agency, namespace) }
      assert_equal reference, issued
      assert_match ReferenceSequence.reference_pattern(namespace), issued
    end
  end

  test "widening types grow past their minimum width" do
    sequence(:departure).update!(next_value: 12_345)
    assert_equal "DEP-12345", issue_reference!(@agency, "departure")
    sequence(:trip).update!(next_value: 1_234_567)
    assert_equal "T-1234567", issue_reference!(@agency, "trip")
    assert_match Departure::REFERENCE_FORMAT, "DEP-12345"
    assert_no_match Departure::REFERENCE_FORMAT, "D-000001"
    assert_no_match Departure::REFERENCE_FORMAT, "DEP-001"
  end

  test "client and supplier keep the six-digit limit" do
    sequence(:client).update!(next_value: ReferenceSequence::EXHAUSTED_AT)
    error = assert_raises(AgencyCommand::Error) { issue_reference!(@agency, "client") }
    assert_equal :reference_exhausted, error.code
    assert_raises(ActiveRecord::StatementInvalid) do
      ReferenceSequence.transaction(requires_new: true) do
        ReferenceSequence.where(id: sequence(:supplier).id).update_all(next_value: ReferenceSequence::EXHAUSTED_AT + 1)
      end
    end
  end

  test "a rollback returns the number" do
    ReferenceSequence.transaction(requires_new: true) do
      issue_reference!(@agency, "invoice")
      raise ActiveRecord::Rollback
    end
    assert_equal "INV-00001", ReferenceSequence.transaction { issue_reference!(@agency, "invoice") }
  end

  test "gapless types refuse to issue outside a transaction" do
    connection = ReferenceSequence.connection
    connection.define_singleton_method(:transaction_open?) { false }
    begin
      assert_raises(ArgumentError) { issue_reference!(@agency, "invoice") }
      assert_raises(ArgumentError) { issue_reference!(@agency, "receipt") }
    ensure
      connection.singleton_class.remove_method(:transaction_open?)
    end
    assert_equal 1, sequence(:invoice).reload.next_value
  end

  test "the database refuses an unknown namespace" do
    assert_raises(ActiveRecord::StatementInvalid) do
      ReferenceSequence.transaction(requires_new: true) do
        ReferenceSequence.where(id: sequence(:trip).id).update_all(namespace: "booking")
      end
    end
  end

  private

  def sequence(namespace)
    @agency.reference_sequences.find_by!(namespace: namespace.to_s)
  end
end
