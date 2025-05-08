require 'rspec/expectations'

# This matcher compares individual elements of Arrays or Numo::NArrays of the
# same size, failing if any pair of elements has an absolute value difference
# greater than or equal to +max_delta+.
#
# If .sigfigs is added before .of_array, then the delta given will be treated
# as a number of digits, and the log10 is compared instead.  This is useful for
# comparing floating point values of unknown magnitudes.  The difference is
# given in number of matching digits when in sigfigs mode.  In other words, the
# match succeeds if the absolute difference is within the expected value
# divided by 10 ** (max_delta - 1).  So 12345 will match 12357 with sigfigs of
# 4 but not 12358.
#
# Example:
#     expect(Numo::SFloat[1,2,3]).to all_be_within(3).of_array([0, 1, 2])
#
#     expect([12357]).to all_be_within(4).sigfigs.of_array([12345])
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

    next true if na_actual.length == 0

    if @sigfigs
      diff = na_actual.map_with_index { |v, idx|
        v2 = na_expected[idx]

        if v2.abs == 0
          scale = 0
        else
          scale = Math.log10(v2.abs)
        end

        d = (v - v2).abs

        # Number of matching digits
        d == 0 ? Float::INFINITY : scale - Math.log10(d) + 1
      }

      absdiff = diff.abs
      idx = absdiff.max_index
      delta = absdiff.min
      idx = absdiff.min_index
      failure = delta < max_delta
    else
      diff = na_actual - na_expected
      absdiff = diff.abs
      delta = absdiff.max
      idx = absdiff.max_index
      failure = delta > max_delta
    end

    if diff.respond_to?(:isnan) && diff.isnan.count_1 != 0
      @msg = 'some elements of either array were NaN (not a number)'
      next false
    end

    if failure
      expected_at_idx = na_expected.is_a?(Numeric) ? na_expected : na_expected[idx]
      actual_at_idx = na_actual[idx]

      @msg = "the maximum difference was #{delta} at index #{absdiff.max_index} (value=#{actual_at_idx} expected=#{expected_at_idx})"

      next false
    end

    true
  end

  chain :sigfigs do
    @sigfigs = true
  end

  chain :of_array do |expected|
    @expected = expected
  end

  failure_message do
    if @sigfigs
      "expected all elements of #{actual.inspect} to match at least #{@max_delta} significant figures of #{@expected.inspect}, but #{@msg}"
    else
      "expected all elements of #{actual.inspect} to be within #{@max_delta} of #{@expected.inspect}, but #{@msg}"
    end
  end

  # FIXME: is this even doing anything?
  diffable
end
