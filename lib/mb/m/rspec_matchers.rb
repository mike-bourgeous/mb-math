# This file defines RSpec matchers.

require 'rspec/expectations'

# This matcher compares individual elements of Arrays or Numo::NArrays of the
# same size, failing if any pair of elements has an absolute value difference
# greater than or equal to +max_delta+.
#
# Example:
#     expect(Numo::SFloat[1,2,3]).to all_be_within([
RSpec::Matchers.define :all_be_within do |max_delta|
  match do |actual|
    @max_delta = max_delta

    begin
      na_actual = Numo::NArray.cast(actual)
    rescue => e
      @msg = "actual result could not be converted to Numo::NArray: #{e}"
      next false
    end

    begin
      if @expected.is_a?(Numeric)
        na_expected = @expected
      else
        na_expected = Numo::NArray.cast(@expected)
      end
    rescue => e
      @msg = "expected value could not be converted to Numo::NArray: #{e}"
      next false
    end

    if !na_expected.is_a?(Numeric) && na_actual.length != na_expected.length
      @msg = 'their lengths differ'
      next false
    end

    diff = na_actual - na_expected

    if diff.respond_to?(:isnan) && diff.isnan.count_1 != 0
      @msg = 'some elements of either array were NaN (not a number)'
      next false
    end

    absdiff = diff.abs

    delta = absdiff.max
    if delta > max_delta
      idx = absdiff.max_index
      expected_at_idx = na_expected.is_a?(Numeric) ? na_expected : na_expected[idx]
      actual_at_idx = na_actual[idx]

      @msg = "the maximum difference was #{delta} at index #{absdiff.max_index} (value=#{actual_at_idx} expected=#{expected_at_idx})"

      next false
    end

    true
  end

  chain :of_array do |expected|
    @expected = expected
  end

  failure_message do
    "expected all elements of #{actual} to be within #{@max_delta} of #{@expected}, but #{@msg}\n#{super()}"
  end

  # FIXME: is this even doing anything?
  diffable
end
