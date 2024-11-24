module MB
  module M
    # Methods for generating or working with random values.
    module RandomMethods
      extend self

      # Returns a random Numeric value with components in the given +range+
      # (defaults to 0..1 for scalars, always 0..2pi for angles).
      #
      # +range+ - The range of values to sample.  Range also controls the type
      # of scalars generated.  Use Integers to generate integers (or
      # rationals), Floats to generate floats, Rationals to generate rationals.
      # The default denominator range for Rational is from 1 to 10000, but you
      # can specify a larger denominator range by using a larger denominator as
      # a range endpoint.
      #
      # +:complex+ - If true or :rect, generates complex numbers with a uniform
      # distribution of real and imaginary part.  If :polar, generates complex
      # numbers with a uniform distribution of radius within the range
      # specified, and a uniform angle from 0..2pi.
      def random_value(range = 0.0..1.0, complex: false)
        range ||= 0.0..1.0

        case complex
        when :polar
          # TODO: Maybe allow specifying separate ranges for angle and magnitude
          # TODO: For a uniform distribution we should probably generate random
          # rectangular complex values and discard them until we get one that
          # lies within the specified range.
          return Complex.polar(random_value(range), random_value(0...(2 * Math::PI)))

        when true, :rect
          return Complex(random_value(range), random_value(range))
        end

        if range.begin.is_a?(Float) || range.end.is_a?(Float)
          rand(range)
        elsif range.begin.is_a?(Rational) || range.end.is_a?(Rational)
          # TODO: Allow specifying the denominator range
          span = range.end - range.begin
          denom_max = MB::M.max(10000, MB::M.max(range.begin.denominator, range.end.denominator))
          denominator = rand(1..denom_max) while denominator.nil? || denominator == 0

          numrange = range.exclude_end? ? 0...(span * denominator) : 0..(span * denominator)
          numerator = rand(Rational(0, denominator)..(span * denominator))

          Rational(numerator, denominator) + range.begin
        else
          rand(range)
        end
      end
    end
  end
end
