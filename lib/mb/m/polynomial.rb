# TODO: try to remove fft dependency
require 'numo/pocketfft'

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
        # TODO: it might be possible to handle multivariable polynomials by using an N-dimensional array

        coefficients = coefficients[0].dup if coefficients.length == 1 && coefficients[0].is_a?(Array)
        raise ArgumentError, "All coefficients must be Numeric; got #{coefficients.map(&:class).uniq}" unless coefficients.all?(Numeric)

        first_nonzero = coefficients.find_index { |v| v != 0 }
        @coefficients = coefficients[first_nonzero..].map { |c|
          c.is_a?(Complex) && c.imag == 0 ? c.real : c
        }.freeze

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
          return self.dup if other.empty?
          return other.dup if empty?

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
          other = other.to_r if other.is_a?(Integer) # TODO: use to_f instead?
          new_coefficients = @coefficients.map { |c| c / other }

        when Polynomial
          fft_divide(other)

        else
          raise ArgumentError, "Must divide a Polynomial by a Polynomial or Numeric, not #{other.class}"
        end

        self.class.new(new_coefficients)
      end

      # Returns a new Polynomial with the result of dividing this polynomial by
      # the +other+ using deconvolution.
      #
      # FIXME: this only works when there is no remainder
      def fft_divide(other)
        # FIXME TODO: Implement a real polynomial division algorithm instead of using fft/ifft
        length = @order + other.order + 1
        (f1, f2), offset = optimal_pad_fft(Numo::DComplex.cast(@coefficients), Numo::DComplex.cast(other.coefficients), min_length: length)

        # TODO: even if this works, we still need to reshift and de-pad the output, and possibly rescale it
        f3 = f1 / f2
        n3 = Numo::Pocketfft.ifft(f3)

        # FIXME: this is not the right offset and we need to truncate to the
        # correct order.  Rounding to 6 figures is also probably not enough
        # precision.
        shifted = MB::M.round(MB::M.ror(n3, offset), 6)
        new_coefficients = shifted.to_a
      end

      # Returns quotient and remainder Polynomials with the result of dividing
      # this polynomial by the +other+ using long division.
      def long_divide(other)
        raise NotImplementedError, 'TODO'
      end

      # Returns a new Polynomial with all coefficients rounded to the given
      # number of significant figures.
      def sigfigs(digits)
        self.class.new(@coefficients.map { |c|
          MB::M.sigfigs(c, digits)
        })
      end

      # Returns a new Polynomial with all coefficients rounded to the given
      # number of digits after the decimal point, coercing complex coefficients
      # down to reals if possible.
      def round(digits)
        self.class.new(@coefficients.map { |c| MB::M.round(c, digits) })
      end

      # Returns a new Polynomial with all coefficients divided by the
      # highest-order coefficient, making the highest-order coefficient 1.0.
      def normalize
        return Polynomial.new if @coefficients.empty?

        c0 = @coefficients[0]
        return self.dup if c0 == 1

        Polynomial.new(
          @coefficients.map.with_index { |c, idx|
            c = c.to_r if c.is_a?(Integer) && c0.is_a?(Integer)

            idx == 0 ? 1 : c / c0
          }
        )
      end

      # Returns a new Polynomial with all coefficients converted to Float or
      # Complex with Float.
      def to_f
        Polynomial.new(
          @coefficients.map { |c|
            c.is_a?(Complex) ?
              Complex(c.real.to_f, c.imag.to_f) :
              c.to_f
          }
        )
      end

      # Converts types as appropriate to allow arithmetic with Numerics in any
      # order, e.g. by wrapping numeric values as constant Polynomials.
      #
      # This allows things like `5 * p` to work instead of just `p * 5`.
      def coerce(numeric)
        [self.class.new(numeric), self]
      end

      private

      # Experimental: finds an optimal padding in the time/space domain to
      # minimize zeros or small values in the frequency domain.
      #
      # TODO: figure out if this is just an even vs. odd length thing
      def optimal_pad_fft(*narrays, min_length: nil)
        freqmin = nil
        freq = nil
        idx = nil

        min_length ||= narrays.max(&:length)

        for pad in 0..10
          flist = narrays.map { |n| optimal_shift_fft(MB::M.zpad(n, min_length + pad, alignment: 1)) }
          flistmin = flist.map { |f, idx| f.abs.min }.min
          flistshift = flist.sum(&:last)

          freq, freqmin, idx = flist, flistmin, pad if freq.nil? || flistmin > freqmin
        end

        puts "Best padding for starting length #{min_length}: #{idx} with min abs: #{freqmin} and max #{freq.map(&:first).map(&:abs).map(&:max).max}" # XXX

        return freq.map(&:first), flistshift
      end

      # Experimental: finds an optimal shift in the time/space domain to
      # minimize zeros or small values in the frequency domain.
      #
      # TODO: I'm not expecting this to work, because I expect a sample offset
      # to be purely a phase difference.
      #
      # TODO: Could try different padding lengths instead of different shifts
      #
      # TODO: Could try minimizing the difference between two ffts so that
      # small coefficients line up and don't explode as much when divided.
      def optimal_shift_fft(narray)
        freq = nil
        idx = nil

        for offset in 0..(narray.length / 2)
          f = Numo::Pocketfft.fft(MB::M.rol(narray, offset))
          freq, idx = f, -offset if freq.nil? || f.abs.min > freq.abs.min

          f = Numo::Pocketfft.fft(MB::M.ror(narray, offset))
          freq, idx = f, offset if freq.nil? || f.abs.min > freq.abs.min
        end

        puts "Best offset for length #{narray.length}: #{idx} with min #{freq.abs.min} and max #{freq.abs.max}" # XXX

        return freq, idx
      end
    end
  end
end
