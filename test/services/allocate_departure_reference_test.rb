require "test_helper"

class AllocateDepartureReferenceTest < ActiveSupport::TestCase
  test "issues an agency-scoped padded reference" do
    first = nil
    second = nil
    before = nil

    ActiveRecord::Base.transaction do
      agencies(:one).with_lock do
        before = DepartureReferenceCounter.find_by(agency_id: agencies(:one).id)&.last_value.to_i
        first = AllocateDepartureReference.next!(agencies(:one))
        second = AllocateDepartureReference.next!(agencies(:one))
      end
    end

    assert_equal format("D-%06d", before + 1), first
    assert_equal format("D-%06d", before + 2), second
    assert_equal before + 2, DepartureReferenceCounter.find(agencies(:one).id).last_value
  end

  test "agencies do not share a counter" do
    before_one = DepartureReferenceCounter.find_by(agency_id: agencies(:one).id)&.last_value.to_i
    before_two = DepartureReferenceCounter.find_by(agency_id: agencies(:two).id)&.last_value.to_i

    ActiveRecord::Base.transaction do
      agencies(:one).with_lock { AllocateDepartureReference.next!(agencies(:one)) }
    end
    ActiveRecord::Base.transaction do
      agencies(:two).with_lock { AllocateDepartureReference.next!(agencies(:two)) }
    end

    assert_equal before_one + 1, DepartureReferenceCounter.find(agencies(:one).id).last_value
    assert_equal before_two + 1, DepartureReferenceCounter.find(agencies(:two).id).last_value
  end

  test "values beyond six digits remain valid" do
    ActiveRecord::Base.transaction do
      agencies(:one).with_lock do
        DepartureReferenceCounter.create!(agency: agencies(:one), last_value: 999_999)
        assert_equal "D-1000000", AllocateDepartureReference.next!(agencies(:one))
      end
    end
  end
end
