require 'cmath'
require 'numo/narray'

require_relative 'm/version'
require_relative 'm/interpolation_methods'
require_relative 'm/precision_methods'
require_relative 'm/range_methods'
require_relative 'm/array_methods'

module MB
  # Functions for clamping, scaling, interpolating, etc.  Extracted from
  # mb-sound and various other personal projects.
  module M
    extend InterpolationMethods
    extend PrecisionMethods
    extend RangeMethods
    extend ArrayMethods

    module NumericMathDSL
      # Returns the number itself (radians are the default).
      def radians
        self
      end
      alias radian radians

      # Converts degrees to radians.
      def degrees
        self * Math::PI / 180.0
      end
      alias degree degrees
    end

    Numeric.include(NumericMathDSL)

    # Raises the given +value+ to the given +power+, but using the absolute
    # value function to prevent complex results.  Useful for waveshaping.
    def self.safe_power(value, power)
      if value.is_a?(Numo::NArray)
        return value.map { |v| safe_power(v, power) }
      end

      sign = value.positive? ? 1.0 : -1.0
      value.abs ** power * sign
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
