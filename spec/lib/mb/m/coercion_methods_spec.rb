RSpec.describe(MB::M::CoercionMethods, :aggregate_failures) do
  describe '#convert_down' do
    pending
  end

  describe '#float_to_rational' do
    it 'can convert 0.5 to rational' do
      expect(MB::M.float_to_rational(0.5)).to be_a(Rational).and eq(1r/2)
    end

    it 'can convert -12.345 to rational' do
      expect(MB::M.float_to_rational(-12.345)).to be_a(Rational).and eq(-12345r/1000)
    end

    it 'does not convert if the denominator would exceed limits after rounding' do
      expect(MB::M.float_to_rational(Math::PI)).to be_a(Float).and eq(Math::PI)
    end

    it 'accepts different limits for denominator' do
      expect(MB::M.float_to_rational(0.5, max_denom: 2)).to be_a(Rational).and eq(1r/2)
      expect(MB::M.float_to_rational(0.25, max_denom: 2)).to be_a(Float).and eq(0.25)
      expect(MB::M.float_to_rational(0.25, max_denom: 4)).to be_a(Rational).and eq(1r/4)
    end

    it 'accepts different rounding amounts' do
      expect(MB::M.float_to_rational(6.78910111213, round: 0)).to be_a(Integer).and eq(7r)
      expect(MB::M.float_to_rational(6.78910111213, round: 3)).to be_a(Rational).and eq(6789r/1000)
      expect(MB::M.float_to_rational(-6.78910111213, round: 3)).to be_a(Rational).and eq(-6789r/1000)
    end

    context 'with Complex values' do
      it 'can convert a Complex real and imag to Rational' do
        result = MB::M.float_to_rational(1.25-0.5i)
        expect(result.real).to be_a(Rational).and eq(5r/4)
        expect(result.imag).to be_a(Rational).and eq(-1r/2)
      end

      it 'can convert Complex imag when real stays as Float' do
        result = MB::M.float_to_rational(Math::E-0.5i)
        expect(result.real).to be_a(Float).and eq(Math::E)
        expect(result.imag).to be_a(Rational).and eq(-1r/2)
      end

      it 'honors rounding and denominator limit parameters' do
        result = MB::M.float_to_rational(-1.511111+0.2i, round: 1, max_denom: 2)
        expect(result.real).to be_a(Rational).and eq(-3r/2)
        expect(result.imag).to be_a(Float).and eq(0.2)
      end

      # TODO: right now this method cannot recover these fractions
      pending 'can recover 1/3 from float'
      pending 'can recover 1/36 from float'
      pending 'can recover 5/7 from float'
    end
  end
end
