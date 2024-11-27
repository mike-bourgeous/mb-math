require 'set'
require 'prime'
require 'numo/pocketfft'

module MB
  module M
    # Represents a polynomial of arbitrary positive integer order of a single
    # independent variable for purposes of root finding, differentiation, etc.
    class Polynomial
      # Used by #to_s for printing exponents as superscripts.
      #
      # Unicode did not duplicate the superscript 1, 2, or 3 from Latin-1
      # Extended, so we can't just use a range from u2070 to u2079.
      SUPERSCRIPT_DIGITS = [
        "\u2070",
        "\u00b9",
        "\u00b2",
        "\u00b3",
        "\u2074",
        "\u2075",
        "\u2076",
        "\u2077",
        "\u2078",
        "\u2079"
      ].join

      # The coefficients of this polynomial, if any, in descending order of
      # term power.
      attr_reader :coefficients

      # The order of this polynomial, or the highest integer power of the
      # independent variable.
      attr_reader :order

      # Creates a random polynomial of the given +order+ from randomized
      # coefficients.  This is useful for testing or for creating illustrative
      # polynomials for demonstrations.
      #
      # +:complex+ - If true, generates Complex coefficients.  If :polar, those
      # coefficients will be sampled from the unit circle.
      # +:zero_chance+ - The probability from 0..1 that each coefficient will
      # be set to zero.  If this is 1, then all but the first coefficient will
      # be zero.  If this is 0, then no coefficients will be zero.
      # +:range+ - Passed to RandomMethods#random_value; controls the numeric
      # type generated for roots (Integer, Rational, or Float) as well as the
      # actual range.  The range must not be 0..0.
      def self.random(order, complex: false, zero_chance: 0.5, range: -100..100)
        raise 'Coefficient range must allow nonzero' if range.begin == 0 && range.end == 0

        c = [0]

        # Make sure first coefficient is nonzero
        c[0] = MB::M.random_value(range, complex: complex) while c[0] == 0 || c.empty?

        for i in 0...order
          if zero_chance >= 1 || (zero_chance > 0 && rand() < zero_chance)
            c << 0
          else
            v = 0
            v = MB::M.random_value(range, complex: complex) while v == 0
            c << v
          end
        end

        MB::M::Polynomial.new(c)
      end

      # Creates a random polynomial of the given +order+ from random roots and
      # a random scale factor, rather than randomized coefficients.  Returns
      # the new Polynomial, the list of roots, and the scale factor.  This is
      # useful for testing root-finding algorithms.
      #
      # The list of roots is not truly random -- this method tries to avoid
      # highly multiple roots.
      #
      # Note that coefficients can grow *very* quickly if using a large range
      # or orders past 10, eventually exceeding Ruby's big integer limit.
      #
      # +:complex+ - If true, generates Complex coefficients.  If :polar, those
      # coefficients will be sampled from the unit circle.
      # +:range+ - Passed to RandomMethods#random_value; controls the numeric
      # type generated for roots (Integer, Rational, or Float) as well as the
      # actual range.
      # +:denom_range+ - Passed to randomMethods#random_value for random
      # Rationals.
      def self.random_roots(order, complex: false, range: -15..15, denom_range: 1..1000)
        # Try to get more unique roots
        # TODO: this is hackish; there should be a better way
        # TODO: once this is solved maybe pull it out into a helper called semiunique_random_list or something like that
        roots = Set.new

        (order * 4).times do
          roots << MB::M.random_value(range, complex: complex)
          break if roots.count == order
        end

        roots = roots.to_a
        roots << MB::M.random_value(range, complex: complex) until roots.size == order
        roots = roots.sort_by { |r| [r.real, r.imag] }

        scale = 0
        scale = MB::M.random_value(range, complex: complex, denom_range: denom_range) while scale == 0

        p = from_roots(roots, scale: scale)

        return p, roots, scale
      end

      # Creates a polynomial from the given list of +roots+ (either a variable
      # argument list of Numerics or an Array of Numerics), optionally applying
      # a +:scale+ factor to the final coefficients.
      #
      # This method generates polynomials of the form (x - r) for each root and
      # multiplies them together.
      def self.from_roots(*roots, scale: 1)
        roots = roots[0] if roots.length == 1 && roots[0].is_a?(Array)
        # TODO: for rational roots put denominator on X coefficient?
        roots.map { |r| MB::M::Polynomial.new(1, -r) }.reduce(&:*) * scale
      end

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

        if coefficients.length == 1
          c0 = coefficients[0]
          coefficients = c0.to_a if c0.is_a?(Numo::NArray)
          coefficients = c0.dup if c0.is_a?(Array)
        end
        raise ArgumentError, "All coefficients must be Numeric; got #{coefficients.map(&:class).uniq}" unless coefficients.all?(Numeric)

        @coefficients = coefficients.drop_while(&:zero?).map { |c|
          MB::M.convert_down(c, drop_float: false)
        }.freeze

        # drop_while removes all of the zeros, but we want to keep one if we only got zeros
        @coefficients = [0].freeze if @coefficients.empty? && !coefficients.empty?

        @order = @coefficients.empty? ? 0 : @coefficients.length - 1

        @float = @coefficients.any?(Float)
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
          other = other.to_r if other.is_a?(Integer)
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

        c_self = Numo::DComplex.cast(@coefficients)
        c_other = Numo::DComplex.cast(other.coefficients)

        # Try different padding amounts to minimize or eliminate zero coefficients
        (f1, f2), pad = optimal_pad_fft(
          c_self,
          c_other,
          min_length: length
        )

        f3 = f1 / f2

        # Check for 0 divided by 0 in the DC coefficient.  Not checking for
        # infinity because if other is a factor of self, then any FFT zero in
        # self must also be present in other.
        if f3[0].abs.nan? || (f1[0].abs.round(6) == 0 && f2[0].abs.round(6) == 0)
          # Guess the DC coefficient by adding more padding and looking at the
          # padded area.
          # The DC coefficient will be zero on a product if any of the factors
          # had a zero DC coefficient.

          (f1, f2), pad = optimal_pad_fft(
            c_self,
            c_other,
            min_length: length,
            pad_range: (pad + 1)..(pad + 5)
          )

          f3 = f1 / f2
          f3[0] = 0
          n3 = Numo::Pocketfft.ifft(f3)
          d = MB::M.rol(n3, 1)

          # Remove DC offset; first value should be zero since we know we've zero-padded with rightward alignment
          d -= d[0]
        else
          n3 = Numo::Pocketfft.ifft(f3)
          d = MB::M.rol(n3, 1)
        end

        # FIXME: maybe this shouldn't round at all (but we still need to detect
        # true zeros from very-near zeros to truncate leading zeros, unless we
        # can use the polynomial orders and assume there is no remainder).
        # TODO: maybe we should change the rounding amount based on the number
        # of coefficients, so that we continue to remove leading zeros as
        # overall precision decreases
        d = MB::M.round(d, 12).to_a

        d2 = MB::M.ltrim(d)
        d2
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
        #
        # However, this version collapses all of the rows into a single result
        # row, performing the addition and scaling in-place.
        #
        # The original algorithm is preserved in bin/poly/synthetic_division.rb

        left_count = other.order
        right_count = @order + 1

        # The first row is just the coefficients of the dividend
        result = @coefficients.dup

        c0 = other.coefficients[0]

        for col in 0...right_count
          # Stop writing diagonals and scaling sum if the diagonal will fall
          # off the right (this means we're working on the remainder)
          if col + left_count >= right_count
            next
          end

          # Scale sum by leading coefficient of divisor (non-monic) once column
          # is complete
          if c0 != 1
            sum = result[col]
            sum = sum.to_r if sum.is_a?(Integer) && c0.is_a?(Integer)
            sum = sum.quo(c0)
            sum = sum.numerator if sum.is_a?(Rational) && sum.denominator == 1
            result[col] = sum
          end

          # Fill "diagonal"
          left_count.times do |idx|
            result[col + idx + 1] += result[col] * -other.coefficients[idx + 1]
          end
        end

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

        return quotient, remainder
      end

      # Returns an Array with roots of the polynomial, whether real or complex.
      # In some cases this will preserve exact Rational or Integer roots, but
      # often can only find Float approximations.
      #
      # This method is not always super accurate at this point, but can still
      # be useful to understand a polynomial.  Highly multiple roots (e.g. 4 or
      # more of the same root mixed with a few others) cause this method to
      # struggle more.
      def roots
        case @order
        when 0
          raise RangeError, 'Cannot find roots of a horizontal line'

        when 1
          m = @coefficients[0]
          b = -@coefficients[1]
          m = m.to_r if m.is_a?(Integer) && b.is_a?(Integer)
          root = MB::M.convert_down(b.quo(m))
          [root]

        when 2
          MB::M.quadratic_roots(*@coefficients)

        else
          roots = []
          rest = self.dup

          while rest.order > 2
            begin
              # TODO: Maybe check if the function actually evaluates to zero at the given root
              # TODO: Maybe some day design a version of find_one_root that uses rationals
              r1 = MB::M.find_one_root(5+1i, rest, tolerance: 1e-8, loops: 5, iterations: 40)
              r1 = MB::M.convert_down(MB::M.float_to_rational(r1)) unless @float
              r1 = MB::M.sigfigs(r1, 8) if r1.is_a?(Float)
              rp = MB::M::Polynomial.new(1, -r1)

              result, remainder = rest / rp

              puts "O#{rest.order}: R=#{self.class.num_str(r1, unicode: false)} " \
                "\e[1;36m#{rest.to_s(unicode: true)}\e[0m / " \
                "\e[1;35m#{rp.to_s(unicode: true)}\e[0m = " \
                "\e[1;32m#{result.to_s(unicode: true)}\e[0m + " \
                "\e[1;33m#{remainder.to_s(unicode: true)}\e[0m" if $DEBUG

              # Is this even possible?
              raise MB::M::RootMethods::ConvergenceError, 'Dividing a root did not reduce the order' if rest.order == result.order

              raise MB::M::RootMethods::ConvergenceError, 'There was a remainder after trying to remove a root' if remainder.order != 0

              roots << r1
              rest = result
            rescue => e
              raise e.class, "Finding a root failed; #{rest.to_s(unicode: true)}: #{e}"
            end
          end

          # Switch to quadratic or linear root finding above for the last one or two roots
          if rest.order > 0
            quad_roots = rest.roots

            puts "O#{rest.order}: Use quadratic method: " \
              "\e[1;36m#{rest.to_s(unicode: true)}\e[0m " \
              "roots: #{MB::U.highlight(quad_roots)}" if $DEBUG

            roots.concat(quad_roots)
          end

          roots.sort_by { |r| [r.real, r.imag] }
        end

      rescue => e
        raise e.class, "#{self.to_s(unicode: true)}: #{e}"
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
      #
      # TODO: since this doesn't return a Float maybe it should be renamed.
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
      def to_s(unicode: false)
        return '' if @coefficients.empty?

        return self.class.num_str(@coefficients[0], unicode: unicode) if @order == 0

        s = String.new

        s << "#{self.class.coeff_str(@coefficients[0], unicode: unicode)}#{self.class.var_str('x', @order, unicode: unicode)}"

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
            s << "#{self.class.num_str(c, unicode: unicode)}"
          else
            s << "#{self.class.coeff_str(c, unicode: unicode)}#{self.class.var_str('x', exponent, unicode: unicode)}"
          end
        end

        s
      end

      private

      # Experimental: finds an optimal padding in the time/space domain to
      # minimize NaNs and small values in the frequency domain, and prefer even
      # lengths over odd lengths (odd lengths tend to have weird values in the
      # Nyquist position).
      #
      # TODO: figure out if this is just an even vs. odd length thing
      def optimal_pad_fft(*narrays, min_length: nil, pad_range: 0..3)
        oldnan = nil
        oldbad = nil
        oldodd = nil
        freq = nil
        idx = nil

        min_length ||= narrays.max(&:length)

        raise "Pad range #{pad_range} is empty" if pad_range.end < pad_range.begin

        for pad in pad_range
          flist = narrays.map.with_index { |n, idx| Numo::Pocketfft.fft(MB::M.zpad(n, min_length + pad, alignment: 1.0)) }
          newnan = flist.map { |f| f.isnan.count }.sum
          newbad = flist.map { |f| MB::M.round(f, 6).eq(0).count }.sum
          newodd = flist.map { |f| f.length.odd? ? 1 : 0 }.sum

          if freq.nil? || newnan < oldnan || (newnan == oldnan && (newbad < oldbad || (newbad == oldbad && newodd < oldodd)))
            freq = flist
            oldnan = newnan
            oldbad = newbad
            oldodd = newodd
            idx = pad
          end
        end

        return freq, pad
      end

      # Helper for #to_s to generate text and multiplication symbol for
      # coefficients, with special handling for when the coefficient is equal
      # to 1 or -1 or is an imaginary value.
      def self.coeff_str(c, unicode:)
        case c
        when 1
          ''

        when -1
          '-'

        else
          unisep = c.is_a?(Complex) || c.is_a?(Rational) ? "\u00b7" : ''
          "#{num_str(c, unicode: unicode)}#{unicode ? unisep : ' * '}"
        end
      end

      # Helper for #to_s and #coeff_str to format numbers, e.g. showing complex
      # values without the real part if the real part is zero.
      def self.num_str(c, imag = '', unicode:, unicode_round: 5)
        case c
        when Complex
          if c.real == 0
            num_str(c.imag, 'i', unicode: unicode)
          elsif c.imag == 0
            num_str(c.real, unicode: unicode)
          elsif c.imag < 0
            "(#{num_str(c.real, unicode: unicode)}-#{num_str(-c.imag, 'i', unicode: unicode)})"
          else
            "(#{num_str(c.real, unicode: unicode)}+#{num_str(c.imag, 'i', unicode: unicode)})"
          end

        when Rational
          if c.denominator == 1
            "#{c.numerator}#{imag}"
          else
            if unicode
              "#{superscript(c.numerator)}/#{subscript(c.denominator)}#{imag}"
            else
              "(#{c.numerator}r#{imag}/#{c.denominator})"
            end
          end

        when Float
          if unicode
            "#{c.round(unicode_round)}#{imag}"
          else
            "#{c}#{imag}"
          end

        else
          "#{c}#{imag}"
        end
      end

      # Helper for #to_s to generate text for variable/base and exponent.
      def self.var_str(base, exponent, unicode:)
        case exponent
        when 0
          raise 'Handle zero-order term elsewhere'

        when 1
          base

        else
          if unicode
            "#{base}#{superscript(exponent)}"
          else
            "#{base} ** #{exponent}"
          end
        end
      end

      # Returns +value+ (expected to be an Integer) as a String with Unicode superscript digits.
      def self.superscript(value)
        value.to_s.tr('0-9', SUPERSCRIPT_DIGITS)
      end

      # Returns +value+ (should be an Integer) as a String with Unicode subscript digits.
      def self.subscript(value)
        value.to_s.tr('0-9', "\u2080-\u2089")
      end

      # Color highlights a numeric value or polynomial, using the given +color+ for
      # super/sub/normal digits.
      def self.hlpoly(str, color)
        str = Polynomial.num_str(str, unicode: true) if str.is_a?(Numeric)
        str
          .gsub(%r{[0-9\u2070-\u2079\u00b2\u00b3\u00b9\u2080-\u2089]+([./][0-9\u2070-\u2079\u00b2\u00b3\u00b9\u2080-\u2089]+)?}, "\e[#{color}m\\&\e[22;39m")
          .gsub(/ [+-] /, "\e[39m\\&\e[39m") # TODO: color for operators?
          .gsub('x', "\e[1m\\&\e[22m")
          .gsub('i', "\e[33m\\&\e[39m")
      end

      # Prints two Polynomials vertically separated as numerator and
      # denominator, with the +:prefix+ printed left of the horizontal bar.
      #
      # Returns the printed width of the centerline.
      def self.print_over(num, denom, prefix: nil, column: 0, suffix: nil)
        prefix = prefix.to_s
        suffix = suffix.to_s
        num_str = num.is_a?(Polynomial) ? num.to_s(unicode: true) : num.to_s
        denom_str = denom.is_a?(Polynomial) ? denom.to_s(unicode: true) : denom.to_s
        len = MB::M.max(num_str.length, denom_str.length) + prefix.length + 5

        puts "\e[#{column}C#{hlpoly(num_str.rjust(len), '1;36')}"
        puts "\e[#{column}C\e[36m#{prefix}\e[0m  #{"\u2500" * (len - prefix.length)}#{suffix}"
        puts "\e[#{column}C#{hlpoly(denom_str.rjust(len), '1;35')}"

        len + 2 + suffix.length
      end

      # Converts a prime factorization from Prime.prime_division into a String
      # for display, formatted similarly to #to_s.
      # TODO: this probably belongs elsewhere
      def self.prime_str(value)
        return "((#{prime_str(value.real)})+(#{prime_str(value.imag)})i)" if value.is_a?(Complex)

        value = Prime.prime_division(value) unless value.is_a?(Array)

        value.map { |prime, exponent|
          var_str(num_str(prime, unicode: true), exponent, unicode: true)
        }.join(' + ')
      end

      # Pretty-prints a prime factorization of an Integer or Rational.
      # TODO: this probably belongs elsewhere
      def self.print_prime(value, prefix: nil)
        case value
        when Rational, Complex
          print_over(prime_str(value.numerator), prime_str(value.denominator), prefix: prefix)

        else
          puts "\e[1;36m#{prefix}\e[0m #{hlpoly(prime_str(value), '1;36')}"
        end
      end

      def self.print_value(value, prefix: nil)
        case value
        when Rational
          if value.denominator == 1
            puts "\e[36m#{prefix}\e[0m #{hlpoly(num_str(value.numerator, unicode: true), '1;36')}"
          else
            print_over(num_str(value.numerator, unicode: true), num_str(value.denominator, unicode: true), prefix: prefix)
          end

        when Complex
          if value.real.is_a?(Rational) || value.imag.is_a?(Rational)
            width = print_over(num_str(value.real.numerator, unicode: true), num_str(value.denominator, unicode: true), prefix: prefix)
            STDOUT.write("\e[3A")
            print_over(num_str(value.imag.numerator, unicode: true), num_str(value.imag.denominator, unicode: true), prefix: '+', column: width + 3, suffix: "\e[1;33m\u00b7i\e[0m")
          else
            puts "\e[36m#{prefix}\e[0m #{hlpoly(num_str(value, unicode: true), '1;36')}"
          end

        else
          puts "\e[36m#{prefix}\e[0m #{hlpoly(num_str(value, unicode: true), '1;36')}"
        end
      end
    end
  end
end
