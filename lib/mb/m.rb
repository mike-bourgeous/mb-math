require 'cmath'
require 'numo/narray'

require_relative 'm/version'
require_relative 'm/interpolation_methods'
require_relative 'm/precision_methods'
require_relative 'm/range_methods'

module MB
  # Functions for clamping, scaling, interpolating, etc.  Extracted from
  # mb-sound and various other personal projects.
  module M
    extend InterpolationMethods
    extend PrecisionMethods
    extend RangeMethods

    # Raises the given +value+ to the given +power+, but using the absolute
    # value function to prevent complex results.  Useful for waveshaping.
    def self.safe_power(value, power)
      if value.is_a?(Numo::NArray)
        return value.map { |v| safe_power(v, power) }
      end

      sign = value.positive? ? 1.0 : -1.0
      value.abs ** power * sign
    end

    # Converts a Ruby Array of any nesting depth to a Numo::NArray with a
    # matching number of dimensions.  All nested arrays at a particular depth
    # should have the same size (that is, all positions should be filled).
    #
    # Chained subscripts on the Array become comma-separated subscripts on the
    # NArray, so array[1][2] would become narray[1, 2].
    def self.array_to_narray(array)
      return array if array.is_a?(Numo::NArray)
      narray = Numo::NArray[array]
      narray.reshape(*narray.shape[1..-1])
    end

    # Sets in-place processing to +inplace+ on the given +narray+, then yields
    # the narray to the given block.
    def self.with_inplace(narray, inplace)
      was_inplace = narray.inplace?
      inplace ? narray.inplace! : narray.not_inplace!
      yield narray
    ensure
      was_inplace ? narray.inplace! : narray.not_inplace!
    end

    # Returns an array with the two complex roots of a quadratic equation with
    # the given coefficients.
    def self.quadratic_roots(a, b, c)
      disc = CMath.sqrt(b * b - 4.0 * a * c)
      denom = 2.0 * a
      [
        ((-b + disc) / denom).to_c,
        ((-b - disc) / denom).to_c
      ]
    end
  end
end
