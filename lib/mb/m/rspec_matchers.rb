# This file defines RSpec matchers.

require 'rspec/expectations'

# This matcher compares individual elements of Arrays or Numo::NArrays of the
# same size, failing if any pair of elements has an absolute value difference
# greater than or equal to +max_delta+.
#
# If .sigfigs is added before .of_array, then the delta given will be treated
# as a number of digits, and the log10 is compared instead.  This is useful for
# comparing floating point values of unknown magnitudes.  The difference is
# given in number of matching digits when in sigfigs mode.
#
# Example:
#     expect(Numo::SFloat[1,2,3]).to all_be_within(3).of_array([0, 1, 2])
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
      puts 'sigfigs diff'
      diff = na_actual.map_with_index { |v, idx|
        v2 = na_expected[idx]

        inputs = [v.abs, v2.abs]
        inputs += [v.real.abs, v.imag.abs] if v.respond_to?(:real)
        inputs += [v2.real.abs, v2.imag.abs] if v2.respond_to?(:real)

        if inputs.max == 0
          scale = 0
        else
          # Subtracting log10(0.5) to get within +/- 5 at the target digit
          scale = Math.log10(inputs.max) - Math.log10(0.5)
        end

        d = (v - v2).abs

        d == 0 ? Float::INFINITY : scale - Math.log10(d)
      }

      absdiff = diff.abs
      idx = absdiff.max_index
      delta = absdiff.min
      idx = absdiff.min_index
      failure = delta < max_delta
    else
      puts 'normal diff'
      diff = na_actual - na_expected
      absdiff = diff.abs
      delta = absdiff.max
      idx = absdiff.max_index
      failure = delta > max_delta
    end

    puts "failure=#{failure} delta=#{delta} max_delta=#{max_delta} absdiff=#{absdiff}"

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
    puts "expected all elements of #{actual} to be within #{@max_delta}#{' significant figures' if @sigfigs} of #{@expected}, but #{@msg}\n#{super()}"
    "expected all elements of #{actual} to be within #{@max_delta}#{' significant figures' if @sigfigs} of #{@expected}, but #{@msg}\n#{super()}"
  end

  # FIXME: is this even doing anything?
  diffable
end
