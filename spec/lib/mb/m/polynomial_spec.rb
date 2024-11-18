RSpec.describe(MB::M::Polynomial, :aggregate_failures) do
  let(:o0_empty) { MB::M::Polynomial.new }
  let(:o0) { MB::M::Polynomial.new(42) }
  let(:o1_r) { MB::M::Polynomial.new(Rational(3, 5), Rational(-7, 2)) }
  let(:o2) { MB::M::Polynomial.new(3, 2, 1) }
  let(:o2_2) { MB::M::Polynomial.new(-3, -2, 5) }
  let(:o3) { MB::M::Polynomial.new(2, -1, 3, -5) }
  let(:o100) { MB::M::Polynomial.new((1..101).to_a) }
  let(:c4) { MB::M::Polynomial.new(4.0 + 1.5i, 0, 0, 0, -1i) }

  describe '#initialize' do
    it 'can create a polynomial from an Array' do
      p = MB::M::Polynomial.new([1, 2, 3])
      expect(p.coefficients).to eq([1, 2, 3])
    end

    it 'can create a polynomial from a variable length list' do
      p = MB::M::Polynomial.new(1, 2, 3)
      expect(p.coefficients).to eq([1, 2, 3])
    end

    it 'can create an empty polynomial' do
      p = MB::M::Polynomial.new
      expect(p.coefficients).to eq([])
    end

    it 'raises an error if given non-numeric arguments' do
      expect { MB::M::Polynomial.new([1], [2]) }.to raise_error(ArgumentError, /coefficients.*Numeric/)
    end

    it 'removes leading zeros from coefficients' do
      p = MB::M::Polynomial.new(0, 0, 0, 1, 2)
      expect(p.order).to eq(1)
      expect(p.coefficients).to eq([1, 2])
    end

    it 'can create a polynomial with order 100' do
      expect(o100.order).to eq(100)
    end

    it 'converts Complex to real if the imaginary part is zero' do
      result = MB::M::Polynomial.new(Complex(Rational(3, 2), 0), 1.75 + 0i).coefficients
      expect(result).to eq([Rational(3, 2), 1.75])
      expect(result.any?(Complex)).to eq(false)
    end
  end

  describe '#call' do
    let(:second_order) { MB::M::Polynomial.new(4, 0, -2) }

    it 'returns zero for an empty polynomial' do
      expect(MB::M::Polynomial.new.call(135235)).to eq(0)
      expect(MB::M::Polynomial.new.call(-15)).to eq(0)
      expect(MB::M::Polynomial.new.call(1.0 + 1.0i)).to eq(0)
    end

    it 'can evaluate a zero-order polynomial as a constant value' do
      expect(MB::M::Polynomial.new(42).call(7)).to eq(42)
      expect(MB::M::Polynomial.new(42).call(-1i)).to eq(42)
    end

    it 'can evaluate a second-order polynomial' do
      expect(second_order.call(0)).to eq(-2)
      expect(second_order.call(1)).to eq(2)
      expect(second_order.call(-2)).to eq(14)
    end

    it 'can evaluate a second-order polynomial with a complex input' do
      expect(second_order.call(1i)).to eq(-6)
    end

    it 'can evaluate a 100-order polynomial' do
      expect(o100.call(0)).to eq(101)
    end

    it 'can evaluate a polynomial with complex coefficients' do
      expected = (5+3i) ** 4 * (4.0+1.5i) - 1i
      expect(c4.call(5+3i)).to eq(expected)
    end
  end

  describe '#prime' do
    it 'can calculate a simple derivative of a second-order polynomial' do
      p = MB::M::Polynomial.new(3, 6, 2)
      p_prime = p.prime
      expect(p_prime.coefficients).to eq([6, 6])
      expect(p_prime.call(1)).to eq(12)
    end

    it 'can calculate a higher-order derivative' do
      p = MB::M::Polynomial.new(3, 2, 1, 0)
      p_prime2 = p.prime(2)
      expect(p_prime2.coefficients).to eq([18, 4])
    end
  end

  describe '#+' do
    it 'can add a polynomial of lesser order' do
      s = o3 + o2
      expect(s.coefficients).to eq([2, 2, 5, -4])
      expect(s.order).to eq(3)
    end

    it 'can add a polynomial of greater order' do
      s = o2 + o3
      expect(s.coefficients).to eq([2, 2, 5, -4])
      expect(s.order).to eq(3)
    end

    it 'cancels leading zeros' do
      s = o2 + o2_2
      expect(s.coefficients).to eq([6])
      expect(s.order).to eq(0)

      s_swap = o2_2 + o2
      expect(s_swap.coefficients).to eq([6])
      expect(s_swap.order).to eq(0)
    end

    it 'can add Numerics' do
      expect((o3 + 1).coefficients).to eq([2, -1, 3, -4])
      expect((o3 + 1i).coefficients).to eq([2, -1, 3, -5+1i])
      expect((o3 + 1r/2r).coefficients).to eq([2, -1, 3, Rational(-9, 2)])
      expect((o3 + -0.5).coefficients).to eq([2, -1, 3, -5.5])
    end
  end

  describe '#-' do
    it 'can subtract a polynomial of lesser order' do
      s = o3 - o2
      expect(s.coefficients).to eq([2, -4, 1, -6])
      expect(s.order).to eq(3)
    end

    it 'can subtract a polynomial of greater order' do
      s = o2 - o3
      expect(s.coefficients).to eq([-2, 4, -1, 6])
      expect(s.order).to eq(3)
    end

    it 'cancels leading zeros' do
      s = o2 - MB::M::Polynomial.new(3, 2, 2)
      expect(s.coefficients).to eq([-1])
      expect(s.order).to eq(0)
    end

    pending 'can subtract Numerics'

    pending 'with an empty polynomial'
  end

  describe '#-@' do
    it 'negates the coefficients' do
      p = MB::M::Polynomial.new(3,2,1,0)
      pneg = -p

      expect(pneg.coefficients).to eq([-3,-2,-1,-0])
      expect(pneg.call(5)).to eq(-p.call(5))
    end

    pending 'with an empty polynomial'
  end

  describe '#*' do
    it 'can multiply zero-order constants' do
      p = MB::M::Polynomial.new(3) * MB::M::Polynomial.new(-1i)
      expect(p.coefficients).to eq([-3i])
    end

    it 'can multiply longer polynomials' do
      p = o2 * o3
      expect(p.coefficients).to eq([6, 1, 9, -10, -7, -5])

      p = o3 * o2
      expect(p.coefficients).to eq([6, 1, 9, -10, -7, -5])
    end

    context 'with Numeric' do
      it 'can multiply by a Complex' do
        p = MB::M::Polynomial.new(2, -2) * 5i
        expect(p.coefficients).to eq([10i, -10i])
      end

      it 'can multiply by a Rational' do
        expect((o2 * Rational(1, 2)).coefficients).to eq([Rational(3, 2), 1, Rational(1, 2)])
      end
    end

    context 'with empty polynomials' do
      it 'can multiply an order-0 polynomial and an empty polynomial' do
        expect((o0_empty * o0).coefficients).to eq([42])
      end

      it 'can multiply an empty polynomial by a longer polynomial' do
        expect((o0_empty * o2).coefficients).to eq([3, 2, 1])
      end

      it 'returns an empty polynomial when multiplying two empty polynomials' do
        expect((o0_empty * o0_empty).coefficients).to eq([])
      end
    end
  end

  describe '#/' do
    it 'can divide by a Numeric' do
      p = o2 / 3.0
      expect(p.coefficients).to eq([1.0, 2.0 / 3.0, 1.0 / 3.0])
    end

    it "can step down Pascal's triangle" do
      p1 = MB::M::Polynomial.new(1, 1)
      p2 = MB::M::Polynomial.new(1, 4, 6, 4, 1)

      result = p2 / p1

      expect(MB::M.round(result.coefficients, 6)).to eq([1, 3, 3, 1])
    end

    it 'can replicate the example from Wikipedia' do
      # https://en.wikipedia.org/wiki/Polynomial_long_division#Example
      p1 = MB::M::Polynomial.new(1, -3)
      p2 = MB::M::Polynomial.new(1, -2, 0, -9) # FIXME: -9 should be -4 to give remainder of 5

      result = p2 / p1

      # FIXME: remainders??
      expect(MB::M.round(result.coefficients, 6)).to eq([1, 1, 3]) # remainder=5?
    end

    pending 'can divide by a Numeric'

    pending 'with empty polynomials'
  end

  describe '#round' do
    it 'rounds coefficients' do
      p = MB::M::Polynomial.new(3, 2.001, 1.9+1.0001i)
      expect(p.round(3).coefficients).to eq([3, 2.001, 1.9+1.0i])
      expect(p.round(0).coefficients).to eq([3, 2, 2+1i])
    end
  end

  describe '#sigfigs' do
    it 'rounds coefficients after significant figures' do
      p = MB::M::Polynomial.new(34567, 2.001, 1.9111111+0.000123456i)
      expect(p.sigfigs(3).coefficients).to eq([34600, 2.0, 1.91+0.000123i])
      expect(p.sigfigs(1).coefficients).to eq([30000, 2.0, 2.0+0.0001i])
    end
  end

  describe '#coerce' do
    context 'with Numeric' do
      pending 'allows addition'
      pending 'allows subtraction'
      pending 'allows multiplication'
      pending 'allows division' # TODO: only if order is zero?
    end
  end

  describe '#fft_divide' do
    pending
  end

  describe '#long_divide' do
    pending
  end

  describe '#normalize' do
    pending 'converts Integer to Rational'
    pending
  end

  describe '#to_f' do
    it 'converts Rational values' do
      result = o1_r.to_f.coefficients
      expect(result).to eq([0.6, -3.5])
      expect(result).to all(be_a(Float))
    end

    it 'converts Complex values' do
      expect((o1_r * 1i).to_f.coefficients).to eq([0.6i, -3.5i])
    end
  end

  pending '#to_s'
end
