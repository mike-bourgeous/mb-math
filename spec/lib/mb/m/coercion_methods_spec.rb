RSpec.describe(MB::M::CoercionMethods, :aggregate_failures) do
  describe '#convert_down' do
    context 'with Floats' do
      it 'converts integer Floats to Integers' do
        expect(MB::M.convert_down(1337.0)).to eq(1337).and be_a(Integer)
        expect(MB::M.convert_down(-42.0)).to eq(-42).and be_a(Integer)
      end

      it 'does not convert non-integer Float to another type' do
        expect(MB::M.convert_down(0.5)).to eq(0.5).and be_a(Float)
        expect(MB::M.convert_down(-1.5)).to eq(-1.5).and be_a(Float)
        expect(MB::M.convert_down(Math::PI)).to eq(Math::PI).and be_a(Float)
      end

      it 'does not convert to Integer if :drop_float is false' do
        expect(MB::M.convert_down(-6.0, drop_float: false)).to eq(-6.0).and be_a(Float)
        expect(MB::M.convert_down(5.0, drop_float: false)).to eq(5.0).and be_a(Float)
      end
    end

    context 'with Rationals' do
      it 'converts degenerate Rationals to Integers' do
        expect(MB::M.convert_down(Rational(10, 2))).to eq(5).and be_a(Integer)
      end

      it 'does not convert Rationals where the denominator is not 1' do
        expect(MB::M.convert_down(Rational(5, 2))).to eq(5r/2).and be_a(Rational)
      end
    end

    context 'with Integers' do
      it 'returns the value unmodified' do
        expect(MB::M.convert_down(0)).to eq(0).and be_a(Integer)
        expect(MB::M.convert_down(-12345)).to eq(-12345).and be_a(Integer)
      end
    end

    context 'with Complex' do
      it 'returns the real component if the imaginary component is zero' do
        expect(MB::M.convert_down(Complex(1.25, 0))).to eq(1.25).and be_a(Float)
        expect(MB::M.convert_down(Complex(-2.0, 0))).to eq(-2).and be_a(Integer)
        expect(MB::M.convert_down(Complex(7r/11, 0))).to eq(7r/11).and be_a(Rational)
      end

      it 'converts the real and imaginary components to lower types if possible' do
        c = Complex(42.0, 10r/2)
        result = MB::M.convert_down(c)
        expect(result).to eq(Complex(42, 5))
        expect(result.real).to eq(42).and be_a(Integer)
        expect(result.imag).to eq(5).and be_a(Integer)

        c2 = 0.0 + 5ri/7
        r2 = MB::M.convert_down(c2)
        expect(r2).to eq(Complex(0, 5r/7))
        expect(r2.real).to eq(0).and be_a(Integer)
        expect(r2.imag).to eq(5r/7).and be_a(Rational)
      end

      it 'honors the :drop_float parameter' do
        c = Complex(42.0, 10r/2)
        result = MB::M.convert_down(c, drop_float: false)
        expect(result).to eq(Complex(42, 5))
        expect(result.real).to eq(42).and be_a(Float)
        expect(result.imag).to eq(5).and be_a(Integer)

        c2 = 0.0 + 5ri/7
        r2 = MB::M.convert_down(c2, drop_float: false)
        expect(r2).to eq(Complex(0, 5r/7))
        expect(r2.real).to eq(0).and be_a(Float)
        expect(r2.imag).to eq(5r/7).and be_a(Rational)
      end
    end

    context 'with an Array' do
      let(:mixed) { [5r/3, 1.5, 10r/2, -7.0, 42] }

      it 'converts values in the array' do
        expect(MB::M.convert_down([1,2,3,4,5])).to eq([1,2,3,4,5]).and be_a(Array).and all(be_a(Integer))

        expect(MB::M.convert_down([1,2,3,4,5])).to eq([1,2,3,4,5]).and be_a(Array).and all(be_a(Integer))
        expect(MB::M.convert_down([1.5,2.5,3.5,4.5,5.5])).to eq([1.5,2.5,3.5,4.5,5.5]).and be_a(Array).and all(be_a(Float))
        expect(MB::M.convert_down([1.5i,2.5i,3.5i,4.5i,5.5i])).to eq([1.5i,2.5i,3.5i,4.5i,5.5i]).and be_a(Array).and all(be_a(Complex))
      end

      it 'can convert an Array with mixed types' do
        result = MB::M.convert_down(mixed)
        expect(result).to be_a(Array).and eq([5r/3, 1.5, 5, -7, 42])
        expect(result.map(&:class)).to eq([Rational, Float, Integer, Integer, Integer])
      end

      it 'honors the :drop_float paramter' do
        expect(MB::M.convert_down([1.0,2.0,3.0,4.0,5.0], drop_float: false)).to eq([1,2,3,4,5]).and be_a(Array).and all(be_a(Float))

        result = MB::M.convert_down(mixed, drop_float: false)
        expect(result).to be_a(Array).and eq([5r/3, 1.5, 5, -7.0, 42])
        expect(result.map(&:class)).to eq([Rational, Float, Integer, Float, Integer])
      end
    end

    context 'with a Numo::NArray' do
      it 'returns values in an Array' do
        expect(MB::M.convert_down(Numo::DFloat[1,2,3,4,5])).to eq([1,2,3,4,5]).and be_a(Array).and all(be_a(Integer))

        expect(MB::M.convert_down(Numo::DComplex[1,2,3,4,5])).to eq([1,2,3,4,5]).and be_a(Array).and all(be_a(Integer))
        expect(MB::M.convert_down(Numo::DComplex[1.5,2.5,3.5,4.5,5.5])).to eq([1.5,2.5,3.5,4.5,5.5]).and be_a(Array).and all(be_a(Float))
        expect(MB::M.convert_down(Numo::DComplex[1.5i,2.5i,3.5i,4.5i,5.5i])).to eq([1.5i,2.5i,3.5i,4.5i,5.5i]).and be_a(Array).and all(be_a(Complex))
      end

      it 'honors the :drop_float paramter' do
        expect(MB::M.convert_down(Numo::DFloat[1,2,3,4,5], drop_float: false)).to eq([1,2,3,4,5]).and be_a(Array).and all(be_a(Float))
        expect(MB::M.convert_down(Numo::DComplex[1,2,3,4,5], drop_float: false)).to eq([1,2,3,4,5]).and be_a(Array).and all(be_a(Float))
      end
    end
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
