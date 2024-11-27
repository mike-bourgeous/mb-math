RSpec.describe(MB::M::NumericExtensions) do
  describe 'NumericMathDSL' do
    describe '#degrees' do
      it 'converts Numeric degrees to radians' do
        expect(0.degrees).to eq(0)
        expect(1.degree.round(6)).to eq((Math::PI / 180.0).round(6))
        expect(90.degrees.round(6)).to eq((Math::PI / 2).round(6))
        expect(180.degrees.round(6)).to eq(Math::PI.round(6))
        expect(-90.degrees.round(6)).to eq((-Math::PI / 2).round(6))
      end
    end

    describe '#radians' do
      it 'makes no change' do
        expect(0.radians).to eq(0)
        expect(1.radian).to eq(1)
        expect(-2.5.radians).to eq(-2.5)
      end
    end

    describe '#to_polar_s' do
      it 'can format an Integer' do
        expect(-2.to_polar_s).to eq("2.0\u2220180.0\u00b0")
      end

      it 'can use more digits' do
        expect(Complex.polar(12.341234, 45.12341234.degrees).to_polar_s(6)).to eq("12.3412\u222045.1234\u00b0")
      end

      it 'can use fewer digits' do
        expect(Complex.polar(1.2341234, 45.12341234.degrees).to_polar_s(1)).to eq("1.0\u222050.0\u00b0")
      end
    end

    describe '#rotation' do
      it 'can return a 90 degree rotation matrix' do
        expect(90.degree.rotation.round(8)).to eq(Matrix[[0, -1], [1, 0]])
      end
    end

    describe '#factorial' do
      it 'can calculate a simple factorial' do
        expect(5.factorial).to eq(5 * 4 * 3 * 2)
      end

      it 'returns 1 for 0' do
        expect(0.factorial).to eq(1)
      end

      it 'returns gamma(n+1) for fractions' do
        expect(5.5.factorial).to eq(Math.gamma(6.5))
      end

      it 'can calculate bigint factorials' do
        expect(57.factorial).to eq(40526919504877216755680601905432322134980384796226602145184481280000000000000)
      end
    end

    describe '#choose' do
      it 'returns expected values for some integers' do
        expect(5.choose(3)).to eq(10)
        expect(11.choose(4)).to eq(330)
        expect(11.choose(11)).to eq(1)
        expect((-2..9).map { |v| 7.choose(v) }).to eq([0, 0, 1, 7, 21, 35, 35, 21, 7, 1, 0, 0])
      end

      it 'returns expected values for some floats' do
        expect(8.35.choose(4).round(8)).to eq(86.8740523437500.round(8))
        expect(6.2.choose(2.2).round(8)).to eq(18.0544000000000.round(8))
      end
    end

    describe '#to_f_or_cf' do
      it 'converts Complex real+imag to Float' do
        c = 5r/2-7ri/4
        result = c.to_f_or_cf
        expect(result.real).to be_a(Float).and eq(2.5)
        expect(result.imag).to be_a(Float).and eq(-1.75)
      end

      it 'converts Rational to Float' do
        expect((11r/4).to_f_or_cf).to be_a(Float).and eq(2.75)
      end
    end

    describe '#abs_r' do
      it 'returns the absolute value of an Integer' do
        expect(-5.abs_r).to eq(5)
      end

      it 'returns the absolute value of a Float' do
        expect(-5.5.abs_r).to eq(5.5)
      end

      it 'returns a Rational magnitude for Rational Complex if possible' do
        # 3/4/5 triangle
        expect((3r/7+4ri/7).abs_r).to be_a(Rational).and eq(5r/7)
      end

      it 'returns an Integer magnitude for Complex if possible' do
        expect(Complex.polar(8, 60.degrees).abs_r).to be_a(Integer).and eq(8)
      end
    end
  end
end
