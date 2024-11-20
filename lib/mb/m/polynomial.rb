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
      # variable, with the last coefficient being a constant.
      #
      # If the coefficient list is empty, then this Polynomial will always
      # evaluate to 0 for addition and subtraction, 1 for multiplication
      # and division as denominator, and 0 for division as numerator.
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
          c = c.real if c.is_a?(Complex) && c.imag == 0
          c = c.numerator if c.is_a?(Rational) && c.denominator == 1
          c
        }.freeze

        @order = @coefficients.empty? ? 0 : @coefficients.length - 1
      end

      # Compares this Polynomial to the +other+ polynomial, returning true if
      # the coefficients and order are the same (even if types differ).
      def ==(other)
        other.order == @order && other.coefficients == @coefficients
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

      # Returns two new Polynomials with quotient and remainder after dividing
      # this polynomial by +other+.  The +other+ value must be a Numeric or
      # Polynomial.
      #
      # Example:
      #     a = MB::M::Polynomial.new(1, 2, 3, 4)
      #     b = MB::M::Polynomial.new(5, 6, 7)
      #     c = MB::M::Polynomial.new(-8, -9)
      #
      #     (a * b + c) / b
      #     # => [MB::M::Polynomial.new(1, 2, 3, 4), MB::M::Polynomial.new(-8, -9)]
      def /(other)
        case other
        when Numeric
          other = other.to_r if other.is_a?(Integer) # TODO: use to_f instead?
          quotient = @coefficients.map { |c| c / other }
          remainder = [0]

        when Polynomial
          quotient, remainder = long_divide(other)

        else
          raise ArgumentError, "Must divide a Polynomial by a Polynomial or Numeric, not #{other.class}"
        end

        return self.class.new(quotient), self.class.new(remainder)
      end

      # Returns an Array with the coefficients of the result of dividing this
      # polynomial by the +other+ using FFT-based deconvolution.
      #
      # FIXME: this only works when there is no remainder
      # TODO: maybe also add a least-squares division algorithm
      def fft_divide(other)
        length = MB::M.max(@order, other.order) + 1
        (f1, f2), (off1, off2), pad = optimal_pad_fft(Numo::DComplex.cast(@coefficients), Numo::DComplex.cast(other.coefficients), min_length: length)

        # TODO: even if this works, we still need to reshift and de-pad the output, and possibly rescale it
        f3 = f1 / f2
        n1 = Numo::Pocketfft.ifft(f1)
        n2 = Numo::Pocketfft.ifft(f2)
        n3 = Numo::Pocketfft.ifft(f3)

        # FIXME: this is not the right offset and we need to truncate to the
        # correct order.  Rounding is also probably not enough precision, and
        # maybe this shouldn't round at all (but we need to detect true zeros
        # from very-near zeros).

        d = MB::M.round(n3.to_a, 12)

        added1 = d.length - @coefficients.length
        added2 = d.length - other.coefficients.length

        # XXX d2 = MB::M.ror(d, off1 + off2 - pad) # XXX 1)

        #require 'pry-byebug'; binding.pry # XXX

        # XXX d2.drop_while(&:zero?)
        d
      end

      # Returns quotient and remainder Arrays with the coefficients of the
      # result of dividing this polynomial by the +other+ using synthetic long
      # division.  Use #/ if you want Polynomials instead of coefficient
      # Arrays.
      #
      # References:
      # https://en.wikipedia.org/wiki/Synthetic_division
      def long_divide(other)
        # Empty polynomials are 0 for addition/subtraction, 1 for
        # multiplication, 0 for division as numerator, 1 for division as
        # denominator.
        return [@coefficients, [0]] if other.empty?

        # Synthetic division uses as many rows above the line as the order of
        # the divisor, plus one.  The first row contains the coefficients of
        # the dividend, and each following row holds one of the divisor
        # coefficients (except the highest order coefficient).
        #
        # Each row has as many columns as the sum of the two polynomial orders
        # plus one.  The first N columns are for the divisor, and the remaining
        # M columns are for the dividend.

        left_count = other.order
        right_count = @order + 1
        row_count = other.order + 1

        result = Array.new(right_count)

        # TODO: in the final implementation we don't really need any columns
        # left of the bar because each row only has one populated left-column
        #
        # TODO: in the final implementation we may only need a single array for
        # the output, as we can maybe just add each new result in place
        rows = Array.new(row_count) { { left: Array.new(left_count), right: Array.new(right_count) } }

        # The first row is just the coefficients of the dividend
        rows[0][:right].replace(@coefficients)

        other.coefficients[1..-1]&.each&.with_index do |c, idx|
          rows[-(idx + 1)][:left][-idx] = -c
        end

        # XXX MB::U.headline('After construction')
        # XXX puts MB::U.table(rows.map { |r| r[:left] + r[:right] } + [Array.new(left_count) + result]) # XXX

        c0 = other.coefficients[0] || 1

        for col in 0...right_count
          # Sum the completed column
          result[col] = rows.map { |r| r[:right][col] || 0 }.sum

          # XXX MB::U.headline("After sum #{col}")
          # XXX puts MB::U.table(rows.map { |r| r[:left] + r[:right] } + [Array.new(left_count) + result]) # XXX

          # Stop writing diagonals and scaling sum if the diagonal will fall
          # off the right (this means we're working on the remainder)
          if col + left_count >= right_count
            # XXX puts "skip diag #{col}"
            next
          end

          # Scale sum by leading coefficient of divisor (non-monic)
          if c0 != 1
            sum = result[col]
            sum = sum.to_r if sum.is_a?(Integer) && c0.is_a?(Integer)
            sum /= c0
            sum = sum.numerator if sum.is_a?(Rational) && sum.denominator == 1
            result[col] = sum
          end

          # Fill diagonal
          left_count.times do |idx|
            rows[-(idx + 1)][:right][col + idx + 1] = result[col] * -other.coefficients[idx + 1]
          end

          # XXX MB::U.headline("After diagonal #{col}")
          # XXX puts MB::U.table(rows.map { |r| r[:left] + r[:right] } + [Array.new(left_count) + result]) # XXX
        end

        # XXX MB::U.headline("After loops")
        # XXX puts MB::U.table(rows.map { |r| r[:left] + r[:right] } + [Array.new(left_count) + result]) # XXX

        # TODO: maybe there's a better way to do the sizing arithmetic rather
        # than having these if cases
        if left_count == 0
          quotient = result
          remainder = [0]
        elsif left_count >= result.length
          quotient = [0]
          remainder = result
        else
          remainder = result[-left_count..-1]
          quotient = result[0...-left_count]
        end

        # XXX require 'pry-byebug'; binding.pry # XXX

        return quotient, remainder
      end

      # TODO
      def roots
        case @order
        when 0
          raise RangeError, 'Cannot find roots of a horizontal line'

        when 1
          m = @coefficients[0]
          b = -@coefficients[1]
          m = m.to_r if m.is_a?(Integer) && b.is_a?(Integer)
          root = b / m
          root = root.numerator if root.is_a?(Rational) && root.denominator == 1
          [root]

        when 2
          # TODO: is there a way to return integers or rationals for rational roots?
          MB::M.quadratic_roots(*@coefficients)

        else
          raise NotImplementedError, 'TODO'
        end
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

      # Returns an Array of Arrays with the coefficient and exponent of each
      # term in this polynomial.
      #
      # Example:
      #     Polynomial.new(5, 4, -3, 2).terms
      #     # =>
      #     [[5, 3], [4, 2], [-3, 1], [2, 0]]
      def terms
        # FIXME: should an empty polynomial be 1 (makes sense for multiplication) or 0 (makes sense for addition)?
        return [[1, 0]] if @coefficients.empty?

        @coefficients.map.with_index { |c, idx|
          [c, order - idx]
        }
      end

      # Returns true if any of the coefficients are Complex.
      def complex?
        @coefficients.any?(Complex)
      end

      # Returns true if the polynomial has no coefficients at all.
      def empty?
        @coefficients.empty?
      end

      # Returns a String representing this Polynomial in Ruby-compatible
      # notation.  Note that "Ruby-compatible" means some variations will look
      # a bit odd, such as Complex numbers with Rational parts.  E.g.
      # Complex(0, 5r/3) will be formatted as (5ri/3) so it can be parsed again
      # by Ruby.  This notation differs from what Complex#to_s or Rational#to_s
      # will produce, as sometimes those notations cannot be parsed directly as
      # Ruby syntax.
      #
      # Returns an empty String for an empty Polynomial.
      def to_s
        return '' if @coefficients.empty?

        return num_str(@coefficients[0]) if @order == 0

        s = String.new

        s << "#{coeff_str(@coefficients[0])}#{var_str(@order)}"

        coefficients.each.with_index do |c, idx|
          # Skip terms with a coefficient of zero and skip the first term since
          # it's handled above
          next if c == 0 || idx == 0

          exponent = order - idx

          case
          when c.is_a?(Complex)
            if c.real > 0 || (c.real == 0 && c.imag >= 0)
              s << ' + '
            else
              s << ' - '
              c = -c
            end

          when c > 0
            s << ' + '

          else
            s << ' - '
            c = -c
          end

          if exponent == 0
            s << "#{num_str(c)}"
          else
            s << "#{coeff_str(c)}#{var_str(exponent)}"
          end
        end

        s
      end

      private

      # Experimental: finds an optimal padding in the time/space domain to
      # minimize zeros or small values in the frequency domain.
      #
      # TODO: figure out if this is just an even vs. odd length thing
      def optimal_pad_fft(*narrays, min_length: nil)
        freqmin = nil
        freq = nil
        off = nil
        idx = nil

        min_length ||= narrays.max(&:length)

        for pad in 0..10
          flist = narrays.map.with_index { |n, idx| optimal_shift_fft(MB::M.zpad(n, min_length + pad, alignment: 1.0)) }
          flistmin = flist.map { |f, idx| f.abs.min }.min
          flistshift = flist.map(&:last)

          freq, freqmin, off, idx = flist, flistmin, flistshift, pad if freq.nil? || flistmin > freqmin
        end

        puts "Best padding for starting length #{min_length}: #{idx} with offsets: #{off}, min abs: #{freqmin} and max #{freq.map(&:first).map(&:abs).map(&:max).max}" # XXX

        return freq.map(&:first), off, idx
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
          freq, idx = f, offset if freq.nil? || f.abs.min > freq.abs.min

          f = Numo::Pocketfft.fft(MB::M.ror(narray, offset))
          freq, idx = f, -offset if freq.nil? || f.abs.min > freq.abs.min
        end

        puts "Best offset for length #{narray.length}: #{idx} with min #{freq.abs.min} and max #{freq.abs.max}" # XXX

        return freq, idx
      end

      # Helper for #to_s to generate text and multiplication symbol for
      # coefficients, with special handling for when the coefficient is equal
      # to 1 or -1 or is an imaginary value.
      def coeff_str(c)
        case c
        when 1
          ''

        when -1
          '-'

        else
          "#{num_str(c)} * "
        end
      end

      # Helper for #to_s and #coeff_str to format numbers, e.g. showing complex
      # values without the real part if the real part is zero.
      def num_str(c, imag = '')
        case c
        when Complex
          if c.real == 0
            num_str(c.imag, 'i')
          elsif c.imag == 0
            num_str(c.real)
          elsif c.imag < 0
            "(#{num_str(c.real)}-#{num_str(-c.imag, 'i')})"
          else
            "(#{num_str(c.real)}+#{num_str(c.imag, 'i')})"
          end

        when Rational
          if c.denominator == 1
            "#{c.numerator}#{imag}"
          else
            "(#{c.numerator}r#{imag}/#{c.denominator})"
          end

        else
          "#{c}#{imag}"
        end
      end

      # Helper for #to_s to generate text for variable and exponent.
      def var_str(exponent)
        case exponent
        when 0
          raise 'Handle zero-order term elsewhere'

        when 1
          'x'

        else
          "x ** #{exponent}"
        end
      end
    end
  end
end
