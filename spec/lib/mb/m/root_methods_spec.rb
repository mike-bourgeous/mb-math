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

    pending 'with real roots'
    pending 'with complex roots'

    pending 'with real min and/or max'
    pending 'with complex min and/or max'
    pending 'with different iteration count'
    pending 'with different range'
  end
end
