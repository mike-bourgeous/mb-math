RSpec.describe(MB::M::Polynomial, :aggregate_failures) do
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

    pending 'with complex coefficients'
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
end
