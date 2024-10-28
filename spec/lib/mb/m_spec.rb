RSpec.describe(MB::M, :aggregate_failures) do
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
  end

  describe '.parse_complex' do
    tests = {
      '+1' => 1.0,
      '-1' => -1.0,
      '3' => 3.0,
      '.123' => 0.123,
      '.5 < -.3' => Complex.polar(0.5, -0.3.degrees),
      '+.5 < +.1' => Complex.polar(0.5, 0.1.degrees),
      '.3-.5i' => 0.3-0.5i,
      '1 + 1i' => 1+1i,
      '1-1.0i' => 1-1i,
      '+1-1i' => 1-1i,
      '-1+1i' => -1+1i,
      '1<5' => Complex.polar(1, 5.degrees),
      '+1<+5' => Complex.polar(1, 5.degrees),
      '1.0<-3.2' => Complex.polar(1, -3.2.degrees),
      '0.323 < +190' => Complex.polar(0.323, 190.degrees),
      'invalid' => ArgumentError,
      true => TypeError,
    }

    tests.each do |k, v|
      if v.is_a?(Numeric)
        it "parses #{k.inspect} correctly" do
          expect(MB::M.round(MB::M.parse_complex(k), 10)).to eq(MB::M.round(v, 10))
        end
      else
        it "raises an error for #{k.inspect}" do
          expect { MB::M.parse_complex(k) }.to raise_error(v)
        end
      end
    end
  end
end
