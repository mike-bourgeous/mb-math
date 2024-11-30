module MB
  module M
    # Methods related to converting between different numeric types like Float,
    # Rational, Integer, or Complex.
    module CoercionMethods
      # Converts Complex to real when the imaginary part is zero, Rational to
      # Integer when the denominator is one, and Float to Integer when the
      # fractional part is zero.  Also converts individual Complex components
      # in the same fashion.
      #
      # If given an Array of values, then each individual value is coerced to a
      # lower type when possible.  If given a Numo::NArray, then the coerced
      # values are returned in a standard Ruby Array.
      #
      # If +:drop_float+ is true, then Floats that are exact integers will be
      # converted to Integer.
      def convert_down(value, drop_float: true)
        if value.is_a?(Array) || value.is_a?(Numo::NArray)
          # TODO: should this also downconvert the Numo::NArray type?  NArray
          # doesn't have a rational type so what would we do there?
          return value.to_a.map { |v| convert_down(v, drop_float: drop_float) }
        end

        value = value.real if value.is_a?(Complex) && value.imag == 0
        value = Complex(convert_down(value.real, drop_float: drop_float), convert_down(value.imag, drop_float: drop_float)) if value.is_a?(Complex)
        value = value.numerator if value.is_a?(Rational) && value.denominator == 1
        value = value.to_i if drop_float && value.is_a?(Float) && value % 1 == 0

        value
      end

      # Converts the +value+ from Float to Rational if the denominator is less
      # than or equal to +:max_denom+ after rounding to +:round+ digits.
      # Returns the +value+ as is if it cannot be converted.
      #
      # Note that it's possible to use some nonsensical combinations of
      # +:round+ and +:max_denom+.  For example, rounding to 3 decimals and
      # setting +:max_denom+ to 1000 will always convert to Rational, no matter
      # how much precision is lost.
      #
      # If +value+ is Complex, then the real and imaginary values will be
      # converted if possible.
      #
      # See also #convert_down.
      def float_to_rational(value, max_denom: 100000, round: 12)
        if value.is_a?(Complex)
          return Complex(
            float_to_rational(value.real, max_denom: max_denom, round: round),
            float_to_rational(value.imag, max_denom: max_denom, round: round)
          )
        end

        # TODO: is there some way of discovering repeating decimals?  this
        # method can't even convert 1/3 to rational.
        #
        # See https://stackoverflow.com/a/22230266/737303
        # See https://stackoverflow.com/a/66983369/737303
        # See https://stackoverflow.com/a/96035/737303
        # See https://github.com/clord/fraction
        # See https://rubygems.org/gems/fraction-tree

        # TODO: Would it be better to use sigfigs instead of rounding?
        r = Rational(value).round(round)
        r.denominator <= max_denom ? r : value
      end
    end
  end
end
