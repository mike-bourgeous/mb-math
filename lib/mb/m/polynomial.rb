module MB
  module M
    # Represents a polynomial of arbitrary positive integer order of a single
    # independent variable for purposes of root finding, differentiation, etc.
    class Polynomial
      # The coefficients of this polynomial, if any, in descending order of
      # term power.
      attr_reader :coefficients

      # The order of this polynomial, or the highest integer power of the
      # independent variable.
      attr_reader :order

      # Initializes a polynomial with the given +coefficients+, which may be a
      # variable argument list or a single Array.  Coefficients may be any
      # Numeric, including Complex, but some operations may result in
      # conversion to Float (or Complex with Float values).
      #
      # Coefficients correspond to descending powers of the independent
      # variable, with the last coefficient being a constant.  If the
      # coefficient list is empty, then this Polynomial will always evaluate to
      # 0.
      #
      # Example:
      #     # 5*x**2 + x - 6
      #     Polynomial.new(5, 2, -6)
      def initialize(*coefficients)
        # TODO: it might be possible to make this work on vectors by allowing vectors for coefficients
        coefficients = coefficients[0].dup if coefficients.length == 1 && coefficients[0].is_a?(Array)
        raise ArgumentError, "All coefficients must be Numeric" unless coefficients.all?(Numeric)

        first_nonzero = coefficients.find_index { |v| v != 0 }
        @coefficients = coefficients[first_nonzero..].freeze
        @order = @coefficients.empty? ? 0 : @coefficients.length - 1
      end

      # Evaluates the polynomial at the given value +x+, which may be any
      # Numeric, including Complex.
      def call(x)
        @coefficients.each.with_index.sum { |c, idx|
          next 0 if c == 0
          next c if idx == @order
          x ** (@order - idx) * c
        }
      end

      # Returns a new Polynomial object representing the +n+th order
      # derivative of this Polynomial.
      def prime(n = 1)
        raise "Derivative order must be a positive integer" unless n.is_a?(Integer) && n > 0

        self.class.new(
          @coefficients[0..(@order - n)].map.with_index { |c, idx|
            exponent = @order - idx

            n.times do
              c *= exponent
              exponent -= 1
            end

            c
          }
        )
      end

      # Returns a new Polynomial with the result of adding the +other+
      # Polynomial (or Numeric) to this one.
      def +(other)
        case other
        when Numeric
          new_coefficients = @coefficients.empty? ? [0] : @coefficients.dup
          new_coefficients[-1] += other

        when Polynomial
          new_order = MB::M.max(@order, other.order)

          pad_a = MB::M.zpad(@coefficients, new_order + 1, alignment: 1)
          pad_b = MB::M.zpad(other.coefficients, new_order + 1, alignment: 1)

          new_coefficients = pad_a.map.with_index { |v, idx| v + pad_b[idx] }

        else
          raise ArgumentError, "Must add a Polynomial or Numeric to a Polynomial, not #{other.class}"
        end

        self.class.new(new_coefficients)
      end

      # Returns a new Polynomial with the result of subtracting the +other+
      # Polynomial (or Numeric) from this one.
      def -(other)
        # TODO: dedupe with +
        case other
        when Numeric
          new_coefficients = @coefficients.empty? ? [0] : @coefficients.dup
          new_coefficients[-1] -= other

          when Polynomial
          new_order = MB::M.max(@order, other.order)

          pad_a = MB::M.zpad(@coefficients, new_order + 1, alignment: 1)
          pad_b = MB::M.zpad(other.coefficients, new_order + 1, alignment: 1)

          new_coefficients = pad_a.map.with_index { |v, idx| v - pad_b[idx] }

        else
          raise ArgumentError, "Must subtract a Polynomial or Numeric from a Polynomial, not #{other.class}"
        end

        self.class.new(new_coefficients)
      end

      # Returns a new Polynomial with all coefficients negated.
      def -@
        self.class.new(@coefficients.map(&:-@))
      end

      # Returns a new Polynomial scaled by +other+ if given a Numeric, or
      # multiplied by the +other+ polynomial.
      def *(other)
        case other
        when Numeric
          new_coefficients = @coefficients.map { |c| c * other }

        when Polynomial
          # This seems basically like convolution (confirmed by Octave's
          # documentation of its conv() function).
          new_coefficients = MB::M.convolve(@coefficients, other.coefficients)

        else
          raise ArgumentError, "Must multiply a Polynomial by a Polynomial or Numeric, not #{other.class}"
        end

        self.class.new(new_coefficients)
      end

      # Returns a new Polynomial with this polynomial's coefficients divided by
      # +other+ if given a Numeric, or long-divided by the +other+ polynomial.
      #
      # TODO: what happens if there is a remainder?
      def /(other)
        case other
        when Numeric
          new_coefficients = @coefficients.map { |c| c / other }

        when Polynomial
          raise NotImplementedError, 'TODO: division'

        else
          raise ArgumentError, "Must divide a Polynomial by a Polynomial or Numeric, not #{other.class}"
        end

        self.class.new(new_coefficients)
      end

      # Returns a new Polynomial with all coefficients rounded to the given
      # number of significant figures.
      def sigfigs(digits)
        self.class.new(@coefficients.map { |c|
          MB::M.sigfigs(c, digits)
        })
      end

      # Returns a new Polynomial with all coefficients rounded to the given
      # number of digits after the decimal point.
      def round(digits)
        self.class.new(@coefficients.map { |c|
          MB::M.round(c, digits)
        })
      end

      # Converts types as appropriate to allow arithmetic with Numerics in any
      # order, e.g. by wrapping numeric values as constant Polynomials.
      #
      # This allows things like `5 * p` to work instead of just `p * 5`.
      def coerce(numeric)
        [self.class.new(numeric), self]
      end

      # TODO: addition, subtraction, multiplication, division
    end
  end
end
