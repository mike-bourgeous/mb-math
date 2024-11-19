RSpec.describe(MB::M::Polynomial, :aggregate_failures) do
  let(:o0_empty) { MB::M::Polynomial.new }
  let(:o0_zero) { MB::M::Polynomial.new(0) }
  let(:o0_one) { MB::M::Polynomial.new(1) }
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

    it 'converts Rational to Integer if the denominator is one' do
      c0 = MB::M::Polynomial.new(6r/2).coefficients[0]
      expect(c0).to be_a(Integer).and eq(3)
    end
  end

  describe '#==' do
    it 'returns true for identical polynomials' do
      expect(o0_empty == o0_empty).to eq(true)
      expect(o0 == o0).to eq(true)
      expect(o1_r == o1_r).to eq(true)
      expect(o2 == o2).to eq(true)
      expect(c4 == c4).to eq(true)
      expect(o100 == o100).to eq(true)
    end

    it 'returns true for duplicated polynomials' do
      expect(o0_empty.dup == o0_empty).to eq(true)
      expect(o0.dup == o0).to eq(true)
      expect(o1_r.dup == o1_r).to eq(true)
      expect(o2.dup == o2).to eq(true)
      expect(c4.dup == c4).to eq(true)
      expect(o100.dup == o100).to eq(true)

      expect(o0_empty == o0_empty.dup).to eq(true)
      expect(o0 == o0.dup).to eq(true)
      expect(o1_r == o1_r.dup).to eq(true)
      expect(o2 == o2.dup).to eq(true)
      expect(c4 == c4.dup).to eq(true)
      expect(o100 == o100.dup).to eq(true)
    end

    it 'returns false for different polynomials' do
      expect(o0_zero == o0_empty).to eq(false)
      expect(o0_one == o0_empty).to eq(false)
      expect(o0 == o0_empty).to eq(false)
      expect(o2 == o1_r).to eq(false)
      expect(o0 == o0_zero).to eq(false)
      expect(c4 == o100).to eq(false)
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

    it 'can differentiate with complex coefficients' do
      p = MB::M::Polynomial.new(2i, 3+5i, 6, -2i)

      p_prime = p.prime
      expect(p_prime.coefficients).to eq([6i, 6+10i, 6])

      p_prime2 = p.prime(2)
      expect(p_prime2.coefficients).to eq([12i, 6+10i])
    end

    it 'preserves the precision of Rational coefficients' do
      p = MB::M::Polynomial.new(-6r/27, 5r/3, -1r/7, 13r/10, 1r/5)
      p_prime = p.prime
      expect(p_prime.coefficients).to eq([-24r/27, 5, -2r/7, 13r/10])
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

    it 'raises an error if given something other than Numeric or Polynomial' do
      expect { o3 + 'hi' }.to raise_error(ArgumentError, /Must add/)
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

    context 'with a Numeric' do
      it 'subtracts the numeric from the final coefficient' do
        a = MB::M::Polynomial.new(1, 2, 3, 4, 5)
        expect((a - 1i).coefficients).to eq([1, 2, 3, 4, 5 - 1i])
        expect((a - -5.0).coefficients).to eq([1, 2, 3, 4, 10])
      end
    end

    context 'with an empty polynomial' do
      it 'returns an equivalent polynomial if an empty is subtracted' do
        expect((o2 - o0_empty).coefficients).to eq(o2.coefficients)
      end

      it 'returns a negated polynomial if subtracted from an empty' do
        expect((o0_empty - o2).coefficients).to eq(o2.coefficients.map(&:-@))
      end
    end

    it 'raises an error if given something other than Numeric or Polynomial' do
      expect { o3 - 'hi' }.to raise_error(ArgumentError, /Must subtract/)
    end
  end

  describe '#-@' do
    it 'negates the coefficients' do
      p = MB::M::Polynomial.new(3,2,1,0)
      pneg = -p

      expect(pneg.coefficients).to eq([-3,-2,-1,-0])
      expect(pneg.call(5)).to eq(-p.call(5))
    end

    it 'does not explode with an empty polynomial' do
      expect((-o0_empty).coefficients).to eq([])
    end
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
        expect((o0 * o0_empty).coefficients).to eq([42])
      end

      it 'can multiply an empty polynomial by a longer polynomial' do
        expect((o0_empty * o2).coefficients).to eq([3, 2, 1])
        expect((o2 * o0_empty).coefficients).to eq([3, 2, 1])
      end

      it 'returns an empty polynomial when multiplying two empty polynomials' do
        expect((o0_empty * o0_empty).coefficients).to eq([])
      end
    end

    it 'raises an error if given a non-Numeric/non-Polynomial type' do
      expect { o3 * 'test' }.to raise_error(ArgumentError, /Must multiply/)
    end
  end

  describe '#/' do
    it 'can divide by a Numeric' do
      p, _r = o2 / 3.0
      expect(p.coefficients).to eq([1.0, 2.0 / 3.0, 1.0 / 3.0])
    end

    it "can step down Pascal's triangle" do
      p1 = MB::M::Polynomial.new(1, 1)
      p2 = MB::M::Polynomial.new(1, 4, 6, 4, 1)

      quotient, _remainder = p2 / p1

      expect(MB::M.round(quotient.coefficients, 6)).to eq([1, 3, 3, 1])
    end

    it 'returns quotient and remainder from example on Polynomial#/ doc comment' do
      a = MB::M::Polynomial.new(1, 2, 3, 4)
      b = MB::M::Polynomial.new(5, 6, 7)
      c = MB::M::Polynomial.new(-8, -9)

      quotient, remainder = (a * b + c) / b
      expect(quotient.coefficients).to eq([1, 2, 3, 4])
      expect(remainder.coefficients).to eq([-8, -9])
    end

    it 'returns quotient and remainder' do
      a = MB::M::Polynomial.new(1, 2, 3)
      b = MB::M::Polynomial.new(4, 5)
      c = MB::M::Polynomial.new(6, -7)

      quotient, remainder = (a * b + c) / b
      expect(quotient.coefficients).to eq([1, 2, 9r/2])
      expect(remainder.coefficients).to eq([-29r/2])
    end

    it 'returns empty if dividing empty by empty' do
      expect(o0_empty / o0_empty).to eq([o0_empty, o0_zero])
    end

    pending 'with empty polynomials'
    pending 'complex'

    it 'raises an error if given a non-Numeric/non-Polynomial type' do
      expect { o3 / 'test' }.to raise_error(ArgumentError, /Must divide/)
    end
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
    it 'allows addition' do
      expect((1 + o0).coefficients).to eq([43])
    end

    it 'allows subtraction' do
      expect((1 - o0).coefficients).to eq([-41])
    end

    it 'allows multiplication' do
      expect((2i * o2).coefficients).to eq([6i, 4i, 2i])
    end

    it 'allows division' do
      expect((84 / o0).map(&:coefficients)).to eq([[2], [0]])
      expect((60 / o2).map(&:coefficients)).to eq([[0], [60]])
    end
  end

  describe '#terms' do
    it 'can return terms for an example polynomial' do
      expect(MB::M::Polynomial.new(5, 4, -3, 2).terms).to eq([[5, 3], [4, 2], [-3, 1], [2, 0]])
    end

    it 'returns a single term of [1, 0] for an empty polynomial' do
      expect(MB::M::Polynomial.new().terms).to eq([[1, 0]])
    end
  end

  describe '#roots' do
    it 'raises an error for order zero' do
      expect { o0_empty.roots }.to raise_error(RangeError, /horizontal/)
      expect { o0.roots }.to raise_error(RangeError, /horizontal/)
    end

    it 'returns one root for order one, preserving rational precision' do
      expect(o1_r.roots).to eq([35r/6])
    end

    pending 'returns quadratic roots'

    pending 'higher order roots'
  end

  describe '#fft_divide' do
    it "can step down Pascal's triangle" do
      p1 = MB::M::Polynomial.new(1, 1)
      p2 = MB::M::Polynomial.new(1, 4, 6, 4, 1)

      result = p2.fft_divide(p1)

      expect(MB::M.round(result, 6)).to eq([1, 3, 3, 1])
    end

    it 'can replicate the example from Wikipedia but without remainder' do
      # https://en.wikipedia.org/wiki/Polynomial_long_division#Example (modified)
      p1 = MB::M::Polynomial.new(1, -3)
      p2 = MB::M::Polynomial.new(1, -2, 0, -9) # FIXME: -9 should be -4 to give remainder of 5

      result = p2.fft_divide(p1)

      expect(MB::M.round(result, 6)).to eq([1, 1, 3])
    end

    pending
  end

  describe '#long_divide' do
    it 'returns the correct result for the Wikipedia linear synthetic division example' do
      # https://en.wikipedia.org/wiki/Synthetic_division#Regular_synthetic_division
      a = MB::M::Polynomial.new(1, -12, 0, -42)
      b = MB::M::Polynomial.new(1, -3)

      expect(a.long_divide(b)).to eq([[1, -9, -27], [-123]])
    end

    it 'returns the correct result for the Wikipedia expanded synthetic division example' do
      # https://en.wikipedia.org/wiki/Synthetic_division#Expanded_synthetic_division
      a = MB::M::Polynomial.new(1, -12, 0, -42)
      b = MB::M::Polynomial.new(1, 1, -3)

      expect(a.long_divide(b)).to eq([[1, -13], [16, -81]])
    end

    it 'returns the correct result for the Wikipedia non-monic division example' do
      # https://en.wikipedia.org/wiki/Synthetic_division#For_non-monic_divisors
      a = MB::M::Polynomial.new(6, 5, 0, -7)
      b = MB::M::Polynomial.new(3, -2, -1)

      expect(a.long_divide(b)).to eq([[2, 3], [8, -4]])
    end

    it 'can divide a modified non-monic example with rational coefficients' do
      # Sage:
      # f(x) = 6*x^3 - 5*x^2 - 7
      # g(x) = -3*x^2 + 2*x - 1
      # f.maxima_methods().divide(g)
      # [-2*x + 1/3, -8/3*x - 20/3]
      a = MB::M::Polynomial.new(6, -5, 0, -7)
      b = MB::M::Polynomial.new(-3, 2, -1)

      result = a.long_divide(b)
      expect(result).to eq([[-2, 1r/3], [-8r/3, -20r/3]])
      expect(result.flatten).to all(be_a(Integer).or be_a(Rational))
    end

    it 'can divide a modified non-monic example with floating point coefficients' do
      # Sage:
      # f(x) = 6*x^3 - 5*x^2 - 7
      # g(x) = -3*x^2 + 2*x - 1
      # f.maxima_methods().divide(g)
      # [-2*x + 1/3, -8/3*x - 20/3]
      a = MB::M::Polynomial.new(6, -5, 0, -7)
      b = MB::M::Polynomial.new(-3.0, 2.0, -1.0)

      result = a.long_divide(b)
      expect(result).to eq([[-2.0, 1.0 / 3.0], [-8.0 / 3.0, -20.0 / 3.0]])
      expect(result.flatten).to all(be_a(Float))
    end

    it 'returns the correct result for the Wikipedia long division example' do
      # https://en.wikipedia.org/wiki/Polynomial_long_division#Polynomial_long_division
      a = MB::M::Polynomial.new(1, -2, 0, -4)
      b = MB::M::Polynomial.new(1, -3)

      expect(a.long_divide(b)).to eq([[1, 1, 3], [5]])
    end

    it 'returns the correct result for the Wikipedia tangent example' do
      # https://en.wikipedia.org/wiki/Polynomial_long_division#Finding_tangents_to_polynomial_functions
      a = MB::M::Polynomial.new(1, -12, 0, -42)
      b = MB::M::Polynomial.new(1, -1)
      b *= b

      expect(a.long_divide(b)).to eq([[1, -10], [-21, -32]])
    end

    it "can step down Pascal's triangle" do
      p1 = MB::M::Polynomial.new(1, 1)
      p2 = MB::M::Polynomial.new(1, 4, 6, 4, 1)

      result = p2.long_divide(p1)

      expect(result).to eq([[1, 3, 3, 1], [0]])
    end

    it 'returns 1 for division by self' do
      expect(o3.long_divide(o3)).to eq([[1], [0] * 3])
      expect(o100.long_divide(o100)).to eq([[1], [0] * 100])
    end

    it 'returns 0 remainder self for division by larger order' do
      expect(o2.long_divide(o3)).to eq([[0], o2.coefficients])
    end

    it 'can divide zero-order polynomials' do
      a = MB::M::Polynomial.new(5)
      b = MB::M::Polynomial.new(3)

      expect(a.long_divide(b)).to eq([[5r/3], [0]])
    end

    it 'can divide first-order polynomials with a constant scale' do
      a = MB::M::Polynomial.new(-25, 10)
      b = MB::M::Polynomial.new(-5, 2)

      expect(a.long_divide(b)).to eq([[5], [0]])
    end

    it 'can divide higher-order polynomials with a constant scale' do
      expect((o100 * -7i).long_divide(o100)).to eq([[-7i], [0] * 100])
    end

    it 'can divide a polynomial by a zero-order polynomial' do
      expect(o3.long_divide(o0)).to eq([[2r/42, -1r/42, 3r/42, -5r/42], [0]])
    end

    it 'can divide a zero-order polynomial by a larger order' do
      expect(o0.long_divide(o2)).to eq([[0], [42]])
    end

    it 'raises a division by zero error when dividing by f(x)=0' do
      expect { o0_one.long_divide(o0_zero) }.to raise_error(ZeroDivisionError)
    end

    it 'can divide polynomials with complex coefficients' do
      a = MB::M::Polynomial.new(5+3i, -1-4i, 0+2i)
      b = MB::M::Polynomial.new(3, 5-1i, -5)
      c = MB::M::Polynomial.new(-3, 5i)
      d = a * b + c

      expect(d.long_divide(b)).to eq([[5+3i, -1-4i, 2i], [-3, 5i]])
      expect(d.long_divide(a)).to eq([[3, 5-1i, -5], [-3, 5i]])
    end

    pending 'empty'
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

  describe '#complex?' do
    it 'returns false for an empty polynomial' do
      expect(o0_empty.complex?).to eq(false)
    end

    it 'returns true if any coefficient is complex' do
      expect(c4.complex?).to eq(true)
    end

    it 'returns true for a zero-order polynomial with a complex value' do
      expect(o0.complex?).to eq(false)
      expect((o0 * 1i).complex?).to eq(true)
    end
  end

  describe '#empty?' do
    it 'returns true for an empty polynomial' do
      expect(o0_empty.empty?).to eq(true)
    end

    it 'returns false for a zero-order polynomial' do
      expect(o0.empty?).to eq(false)
    end
  end

  describe '#to_s' do
    it 'returns an empty String for an empty Polynomial' do
      expect(o0_empty.to_s).to eq('')
    end

    it 'omits coefficients equal to one' do
      p = MB::M::Polynomial.new(1, 1, 1, 1, 1, 1)
      expect(p.to_s).to eq('x ** 5 + x ** 4 + x ** 3 + x ** 2 + x + 1')
    end

    it 'omits coefficients equal to negative one' do
      p = MB::M::Polynomial.new(-1, -1, -1, -1, -1, -1)
      expect(p.to_s).to eq('-x ** 5 - x ** 4 - x ** 3 - x ** 2 - x - 1')
    end

    it 'omits exponent on first-order term' do
      p = MB::M::Polynomial.new(2, 0)
      expect(p.to_s).to eq('2 * x')
    end

    it 'skips zero terms' do
      p = MB::M::Polynomial.new(-5, 0, 5, 0, 0, 2i, 0)
      expect(p.to_s).to eq('-5 * x ** 6 + 5 * x ** 4 + 2i * x')
    end

    it 'returns only the numeric as string for zero-order polynomials' do
      expect(o0.to_s).to eq('42')
      expect(MB::M::Polynomial.new(5r/3).to_s).to eq('(5r/3)')
      expect(MB::M::Polynomial.new(2.5).to_s).to eq('2.5')
      expect(MB::M::Polynomial.new(1+3i).to_s).to eq('(1+3i)')
      expect(MB::M::Polynomial.new(0+(3r/5)*1i).to_s).to eq('(3ri/5)')
      expect(MB::M::Polynomial.new(1i).to_s).to eq('1i')
      expect(MB::M::Polynomial.new(-1i).to_s).to eq('-1i')
      expect(MB::M::Polynomial.new(3i).to_s).to eq('3i')
      expect(MB::M::Polynomial.new(-3i).to_s).to eq('-3i')
    end

    it 'formats complex and rational coefficients as Ruby-parseable code' do
      p = MB::M::Polynomial.new(-37r/15, 1.0+3.0i, 5r/3 * 1i, -3-5i, -3+5i, 16r/7-(3r/5 * 1i), 5i, -5i)
      expect(p.to_s).to eq('(-37r/15) * x ** 7 + (1.0+3.0i) * x ** 6 + (5ri/3) * x ** 5 - (3+5i) * x ** 4 - (3-5i) * x ** 3 + ((16r/7)-(3ri/5)) * x ** 2 + 5i * x - 5i')
      expect(eval("x = 42-37i ; #{p.to_s}")).to eq(p.call(42-37i))
    end

    it 'can format a quadratic polynomial' do
      expect(o2.to_s).to eq('3 * x ** 2 + 2 * x + 1')
      expect(o2_2.to_s).to eq('-3 * x ** 2 - 2 * x + 5')
    end
  end
end
