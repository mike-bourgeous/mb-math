RSpec.describe(MB::M::RootMethods, :aggregate_failures) do
  describe '#quadratic_roots' do
    it 'can find roots of an equation with two real roots' do
      expect(MB::M.quadratic_roots(1, 0, -4).sort).to eq([-2, 2])
    end

    it 'can find roots of an equation with one real root' do
      expect(MB::M.quadratic_roots(1, -2, 1).sort).to eq([1, 1])
    end

    it 'can find complex roots of an equation with no real roots' do
      expect(MB::M.quadratic_roots(1, 0, 1).sort_by { |r| [r.real, r.imag] }).to eq([0-1i, 0+1i])
    end

    it 'returns one real and one complex root when coefficients are complex' do
      roots = MB::M.quadratic_roots(1.0, -4.0-1.0i, 3.0+3.0i)

      expect(roots).to eq([3, 1+1i])
      expect(roots.map(&:class)).to eq([Integer, Complex])
    end

    it 'returns the root of a linear equation if a is zero and b is nonzero' do
      expect(MB::M.quadratic_roots(0, 2, 0)).to eq([0])
      expect(MB::M.quadratic_roots(0, 2, 1)).to eq([-0.5])
    end

    it 'raises RangeError if a and b are zero, regardless of c' do
      expect { MB::M.quadratic_roots(0, 0, 0) }.to raise_error(RangeError)
      expect { MB::M.quadratic_roots(0, 0, 1) }.to raise_error(RangeError)
    end

    it 'returns exact Integers for Integer roots' do
      expect(MB::M.quadratic_roots(1, 0, -9)).to all(be_a(Integer)).and eq([3, -3])
    end

    it 'returns Rationals for Rational roots' do
      expect(MB::M.quadratic_roots(1, 1r/21, -10r/21)).to all(be_a(Rational)).and eq([2r/3, -5r/7])
    end

    it 'returns a Rational for an Integer linear equation' do
      expect(MB::M.quadratic_roots(0, 7, -11)).to all(be_a(Rational)).and eq([11r/7])
    end

    it 'returns a Rational for a Rational linear equation' do
      expect(MB::M.quadratic_roots(0, -7r/3, 11r/2)).to all(be_a(Rational)).and eq([33r/14])
    end

    it 'returns an Integer for a degenerate Rational linear equation' do
      expect(MB::M.quadratic_roots(0, -3r/7, 6r/7)).to all(be_a(Integer)).and eq([2])
    end
  end

  describe '#kind_sqrt' do
    it 'returns a Rational for the square root of a Rational when possible' do
      expect(MB::M.kind_sqrt(25r/9)).to be_a(Rational).and eq(5r/3)
    end

    it 'returns a Float for the square root of a Rational when not a rational square' do
      expect(MB::M.kind_sqrt(3r/2)).to be_a(Float).and eq(Math.sqrt(1.5))
    end

    it 'returns an Integer for the square root of an Integer when possible' do
      expect(MB::M.kind_sqrt(25)).to be_a(Integer).and eq(5)
      expect(MB::M.kind_sqrt(16)).to be_a(Integer).and eq(4)
    end

    it 'returns an Integer for the square root of a square, degenerate Rational' do
      expect(MB::M.kind_sqrt(8r/2)).to be_a(Integer).and eq(2)
    end

    it 'returns a Complex with Integers for the square root of a negative Integer' do
      expect(MB::M.kind_sqrt(-9)).to be_a(Complex).and eq(3i)
      expect(MB::M.kind_sqrt(-16).imag).to be_a(Integer).and eq(4)
    end

    it 'returns a Complex with Rationals for the square root of a negative Rational' do
      expect(MB::M.kind_sqrt(-25r/9)).to be_a(Complex).and eq(5ri/3)
      expect(MB::M.kind_sqrt(-36r/49).imag).to be_a(Rational).and eq(6r/7)
    end

    it 'returns a Complex for the square root of a Complex' do
      expect(MB::M.kind_sqrt(3+5i)).to be_a(Complex).and eq(CMath.sqrt(3+5i))
    end

    it 'returns a Float for the square root of a positive non-square Float' do
      expect(MB::M.kind_sqrt(2.5)).to be_a(Float).and eq(Math.sqrt(2.5))
    end

    it 'returns an Integer for the square root of a positive square Float' do
      expect(MB::M.kind_sqrt(4)).to be_a(Integer).and eq(2)
    end

    it 'returns a BigDecimal for the square root of a BigDecimal' do
      expect(MB::M.kind_sqrt(BigDecimal(10 ** 72))).to be_a(BigDecimal).and eq(BigDecimal(10 ** 36))
    end

    it 'falls back to exponentiation for other/unknown Numerics' do
      ntype = Class.new(Numeric) do
        def <(o)
          false
        end
        def **(o)
          42
        end
      end

      v = ntype.new

      expect(MB::M.kind_sqrt(v)).to eq(42)
    end

    it 'returns the correct value for a very large numerator/denominator' do
      # Example from bin/poly/square_root_issue.rb
      a = (178546357533116207952390480015625r/847172625416039298167350321)
      expect(MB::M.kind_sqrt(a)).to eq((13362123990336125r/29106230010361)).and be_a(Rational)
    end

    it 'can provide an exact answer for a simple perfect rational Complex square' do
      a = 37r/213+4ri/13
      b = a * a
      result = MB::M.kind_sqrt(b)
      expect(result.real).to be_a(Rational).or be_a(Integer)
      expect(result.imag).to be_a(Rational).or be_a(Integer)
    end

    it 'provides an exact answer for a reasonable perfect rational Complex square' do
      # Another example:
      # a = (7303r/13063+8846ri/413)
      a = (795r/181+692948r/8277*1i)
      b = a * a
      result = MB::M.kind_sqrt(b)

      expect(result).to eq(a)
      expect(result.real).to be_a(Rational).or be_a(Integer)
      expect(result.imag).to be_a(Rational).or be_a(Integer)
    end

    it 'can provide exact answers for perfect rational square Complex values' do
      # FIXME: sometimes this returns an exact match for the input value but an intermediate result appears to be irrational
      100.times do
        # FIXME: increasing the denominator increases the likelihood of a fallback to float
        # By definition we are creating perfect squares, and yet sometimes the
        # intermediate steps produce irrational values.
        #
        # For example:
        #     require 'prime'
        #
        #     a = (7303r/13063+8846ri/413)
        #
        #     b = a * a
        #     # b = ((-13343929801401483r/29106230010361)+(129204676ri/5395019))
        #
        #     abs_sq = b.real * b.real + b.imag * b.imag
        #     # abs_sq = (178546357533116207952390480015625r/847172625416039298167350321)
        #
        #     abs = MB::M.kind_sqrt(abs_sq)
        #     # abs = (13362123990336126r/29106230010361)
        #
        #     x_sq = (b.real + abs).quo(2)
        #     # x_sq = (18194188934643r/58212460020722)
        #
        #     y_sq = (-b.real + abs).quo(2) * (b.imag >= 0 ? 1 : -1)
        #     # y_sq = (26706053791737609r/58212460020722)
        #
        #     x = MB::M.kind_sqrt(x_sq)
        #     # x = 0.5590599402893822
        #
        #     y = MB::M.kind_sqrt(y_sq)
        #     # y = 21.418886198547213
        #
        #     r = MB::M.kind_sqrt(b)
        #     # r = (0.5590599402893822+21.418886198547213i)
        #
        #     # The result differs by the last few decimals from the true answer
        #     f = Complex(a.real.to_f, a.imag.to_f)
        #     # f = (0.5590599402893669+21.418886198547217i)
        #
        #     # All powers should be even for x_sq and y_sq to be a perfect square but
        #     # we see several odds in the numerator.
        #     MB::M::Polynomial.print_prime(x_sq)
        #     #    3 + 19 + 41 + 6971 + 1116809
        #     # ─────────────────────────────────
        #     #           2 + 7² + 59² + 13063²
        #
        #     MB::M::Polynomial.print_prime(y_sq)
        #     #     3 + 8902017930579203
        #     # ──────────────────────────
        #     #    2 + 7² + 59² + 13063²
        #
        #     # Working backward, here's what we should see:
        #     ex_x_sq = a.real * a.real
        #     ex_y_sq = a.imag * a.imag
        #     MB::M::Polynomial.print_prime(ex_x_sq, prefix: 'expected x_sq')
        #     MB::M::Polynomial.print_prime(ex_y_sq, prefix: 'expected y_sq')
        #     #                   67² + 109²
        #     # expected x_sq  ───────────────
        #     #                       13063²
        #     #                   2² + 4423²
        #     # expected y_sq  ───────────────
        #     #                     7² + 59²
        #
        #     # And for abs (differs by 1 in the numerator from above):
        #     ex_abs_x = ex_x_sq * 2 - b.real
        #     ex_abs_y = ex_y_sq * 2 + b.real
        #     # ex_abs_x = (13362123990336125r/29106230010361)
        #     # ex_abs_y = (13362123990336125r/29106230010361)
        #
        #     # Working back to abs squared, we match the abs_sq value above:
        #     ex_abs_sq = ex_abs_x * ex_abs_x
        #     # ex_abs_sq = (178546357533116207952390480015625r/847172625416039298167350321)
        #     ex_abs_sq == abs_sq
        #     # => true
        #
        #     # So the fault lies in the square root operation!  It must be
        #     # giving an incorrect answer for this larger value.

        # XXX c = MB::M.random_value(0r..100r, complex: true)
        c = Complex(Rational(rand(0..10000), rand(1..10000)), Rational(rand(0..10000), rand(1..10000)))
        result = MB::M.kind_sqrt(c * c)

        puts "\e[1;32m#{MB::M::Polynomial.num_str(c, unicode: true)} ?= \e[1;33m#{MB::M::Polynomial.num_str(result, unicode: true)}" # XXX

        expect(result).to eq(c)
        expect(result.real).to be_a(Rational).or be_a(Integer)
        expect(result.imag).to be_a(Rational).or be_a(Integer)
      end
    end
  end

  describe '#find_one_root' do
    it 'can find the real roots of a simple quadratic polynomial' do
      expect(MB::M.find_one_root(2) { |x| x ** 2 - 1 }.round(12)).to eq(1)
      expect(MB::M.find_one_root(-2) { |x| x ** 2 - 1 }.round(12)).to eq(-1)
    end

    it 'can find the root of a quintic monomial' do
      expect(MB::M.find_one_root(1) { |x| x ** 5 }.round(12)).to eq(0)
    end

    it 'does not leave the root if the guess is a root' do
      expect(MB::M.find_one_root(0) { |x| x ** 5 }.round(12)).to eq(0)
    end

    it 'does not get stuck if starting where slope is zero' do
      # Interesting thing about this test: math.h's sin(pi) ~= 1.2e-16 so it is
      # impossible to find a value for which sin returns exactly zero
      expect(MB::M.find_one_root(Math::PI / 2) { |x| Math.sin(x) }.round(12))
        .to satisfy { |v| Math.sin(v).round(12) == 0 }
        .and satisfy { |v| [0, Math::PI.round(8)].include?(v.round(8)) }
    end

    it 'can start from a complex guess' do
      expect(MB::M.round(MB::M.find_one_root(1+1i) { |x| CMath.sin(x) }, 12)).to eq(0)
    end

    it 'can find complex roots of a polynomial using a grid of complex guesses' do
      # Coefficients generated with Octave:
      #     pkg load signal
      #     output_precision(10)
      #     [num, denom] = ellip(13, 0.5, 45, 0.5)
      numerator = ->(x) {
        5.242933538422166e-02 * x ** 13 +
        1.278699675738862e-01 * x ** 12 +
        4.144888760836190e-01 * x ** 11 +
        7.184021957886224e-01 * x ** 10 +
        1.263738330945532e+00 * x ** 9 +
        1.645243518510108e+00 * x ** 8 +
        1.956390081554363e+00 * x ** 7 +
        1.956390081554365e+00 * x ** 6 +
        1.645243518510112e+00 * x ** 5 +
        1.263738330945533e+00 * x ** 4 +
        7.184021957886209e-01 * x ** 3 +
        4.144888760836180e-01 * x ** 2 +
        1.278699675738862e-01 * x +
        5.242933538422163e-02
      }

      # Roots (zeros) from Octave:
      #     pkg load signal
      #     output_precision(10)
      #     [z, p, g] = ellip(13, 0.5, 45, 0.5)
      expected_roots = [
        -0.509783300 + 0.860302846i,
        -0.149767566 + 0.988721233i,
        -0.041837580 + 0.999124425i,
        -0.012106248 + 0.999926717i,
        -0.004008680 + 0.999991965i,
        -0.001947212 + 0.999998104i,
        -0.509783300 - 0.860302846i,
        -0.149767566 - 0.988721233i,
        -0.041837580 - 0.999124425i,
        -0.012106248 - 0.999926717i,
        -0.004008680 - 0.999991965i,
        -0.001947212 - 0.999998104i,
        -1.000000000 + 0.000000000i,
      ].map { |r| MB::M.round(r, 6) }.sort_by(&:real).sort_by(&:imag)

      result = (-1..1).step(0.1).flat_map { |im|
        (-1..1).step(0.1).map { |re|
          begin
            r = MB::M.find_one_root(re + 1i * im, iterations: 10, loops: 2, tolerance: 1e-12, &numerator)

            # Result and expected rounded to 6 decimals to ensure match
            MB::M.round(r, 6)
          rescue MB::M::RootMethods::ConvergenceError => e
            puts e if $DEBUG
            next
          end
        }
      }

      result = result.compact.uniq.sort_by(&:real).sort_by(&:imag)

      expect(result).to match_array(expected_roots)
    end

    it 'can find roots of a second-order Polynomial object' do
      p = MB::M::Polynomial.new(1, 0, -1)
      expect(MB::M.find_one_root(3, p).round(12)).to eq(1)
      expect(MB::M.find_one_root(-3, p).round(12)).to eq(-1)
    end

    it 'can find roots of a fifth-order monomial Polynomial object' do
      p = MB::M::Polynomial.new(1, 0, 0, 0, 0, 0)
      expect(MB::M.find_one_root(3, p).round(12)).to eq(0)
      expect(MB::M.find_one_root(-3, p).round(12)).to eq(0)
    end

    pending 'with real roots'
    pending 'with complex roots'

    pending 'with real min and/or max'
    pending 'with complex min and/or max'
    pending 'with different iteration count'
    pending 'with different range'

    pending 'with a callable function object instead of a block'
  end
end
