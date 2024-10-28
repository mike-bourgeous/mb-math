RSpec.describe(MB::M::RootMethods) do
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
      expect(roots.map(&:class)).to eq([Float, Complex])
    end

    it 'returns the root of a linear equation if a is zero and b is nonzero' do
      expect(MB::M.quadratic_roots(0, 2, 0)).to eq([0])
      expect(MB::M.quadratic_roots(0, 2, 1)).to eq([-0.5])
    end

    it 'raises RangeError if a and b are zero, regardless of c' do
      expect { MB::M.quadratic_roots(0, 0, 0) }.to raise_error(RangeError)
      expect { MB::M.quadratic_roots(0, 0, 1) }.to raise_error(RangeError)
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
      # TODO: constrain this further to be either 0 or pi
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
      #     [num, denom] = ellip(13, 0.5, 45, 0.5)
      numerator = ->(x) {
        0.052429 * x ** 13 +
        0.127870 * x ** 12 +
        0.414489 * x ** 11 +
        0.718402 * x ** 10 +
        1.263738 * x ** 9 +
        1.645244 * x ** 8 +
        1.956390 * x ** 7 +
        1.956390 * x ** 6 +
        1.645244 * x ** 5 +
        1.263738 * x ** 4 +
        0.718402 * x ** 3 +
        0.414489 * x ** 2 +
        0.127870 * x +
        0.052429
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
      ].map { |r| MB::M.round(r, 3) }.sort_by(&:real).sort_by(&:imag)

      result = (-1..1).step(0.1).flat_map { |im|
        (-1..1).step(0.1).map { |re|
          r = MB::M.find_one_root(re + 1i * im, iterations: 600, tolerance: 1e-15, &numerator)

          # Result and expected rounded to 6 decimals to ensure match
          MB::M.round(r, 3)
        }
      }.uniq.sort_by(&:real).sort_by(&:imag)

      # FIXME: get this to match at 6 decimals; it currently matches only at 1

      expect(result).to match_array(expected_roots)
    end

    pending 'with real roots'
    pending 'with complex roots'

    pending 'with real min and/or max'
    pending 'with complex min and/or max'
    pending 'with different iteration count'
    pending 'with different range'
  end
end
