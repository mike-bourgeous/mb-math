RSpec.describe(MB::M) do
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

  describe '.sigfigs' do
    it 'raises an error if digits is less than one' do
      expect { MB::M.sigfigs(1, 0) }.to raise_error(/digits/)
    end

    it 'returns 0 for very small values' do
      # denormalized
      expect(MB::M.sigfigs(0.0.next_float, 5)).to eq(0)

      # normalized
      expect(MB::M.sigfigs(Float::MIN, 5)).to eq(0)
    end

    it 'returns 0 if the value is already 0' do
      expect(MB::M.sigfigs(0, 5)).to eq(0)
    end

    it 'rounds a number with positive logarithm correctly' do
      expect(MB::M.sigfigs(12345, 5)).to eq(12345)
      expect(MB::M.sigfigs(12345, 4)).to eq(12350)
      expect(MB::M.sigfigs(12345, 3)).to eq(12300)
      expect(MB::M.sigfigs(12345, 2)).to eq(12000)
      expect(MB::M.sigfigs(12345, 1)).to eq(10000)
    end

    it 'rounds a number slightly greater than 1 correctly' do
      expect(MB::M.sigfigs(1.2345, 5)).to eq(1.2345)
      expect(MB::M.sigfigs(1.2345, 3)).to eq(1.23)
      expect(MB::M.sigfigs(1.2345, 1)).to eq(1)
    end

    it 'rounds a number slightly less than 1 correctly' do
      expect(MB::M.sigfigs(0.97531, 5)).to eq(0.97531)
      expect(MB::M.sigfigs(0.97531, 3)).to eq(0.975)
      expect(MB::M.sigfigs(0.97531, 2)).to eq(0.98)
      expect(MB::M.sigfigs(0.97531, 1)).to eq(1.0)
    end

    it 'rounds a number with negative logarithm correctly' do
      expect(MB::M.sigfigs(0.00012345, 5)).to eq(0.00012345)
      expect(MB::M.sigfigs(0.00012345, 4)).to eq(0.0001235)
      expect(MB::M.sigfigs(0.00012345, 3)).to eq(0.000123)
      expect(MB::M.sigfigs(0.00012345, 2)).to eq(0.00012)
      expect(MB::M.sigfigs(0.00012345, 1)).to eq(0.0001)
    end

    it 'rounds negative numbers correctly' do
      expect(MB::M.sigfigs(-12345, 2)).to eq(-12000)
      expect(MB::M.sigfigs(-0.125, 2)).to eq(-0.13)
    end

    it 'rounds an array' do
      expect(MB::M.sigfigs([12345, 23456], 2)).to eq([12000, 23000])
    end

    it 'rounds a complex value' do
      expect(MB::M.sigfigs(1.2345+1.2345i, 2)).to eq(1.2+1.2i)
    end
  end

  describe '.round' do
    context 'without figs specified' do
      it 'rounds individual numbers' do
        expect(MB::M.round(0.4)).to eq(0)
        expect(MB::M.round(-0.4)).to eq(0)
        expect(MB::M.round(0.5)).to eq(1)
        expect(MB::M.round(-0.5)).to eq(-1)
      end

      it 'rounds Arrays' do
        expect(MB::M.round([-3.4, -2.9, -2.1, 0.4, 1.5])).to eq([-3, -3, -2, 0, 2])
      end

      it 'rounds NArrays' do
        expect(MB::M.round(Numo::SFloat[-3.4, -2.9, -2.1, 0.4, 1.5])).to eq([-3, -3, -2, 0, 2])
      end
    end

    context 'with positive figs' do
      it 'rounds individual numbers' do
        expect(MB::M.round(-0.00125, 1)).to eq(0)
        expect(MB::M.round(-0.00125, 4)).to eq(-0.0013)
        expect(MB::M.round(1.23456, 1)).to eq(1.2)
        expect(MB::M.round(1.23456, 4)).to eq(1.2346)
        expect(MB::M.round(1.23456, 7)).to eq(1.23456)
      end

      it 'rounds Arrays' do
        expect(MB::M.round([-0.00125, 1.23456], 1)).to eq([0, 1.2])
        expect(MB::M.round([-0.00125, 1.23456], 4)).to eq([-0.0013, 1.2346])
        expect(MB::M.round([-0.00125, 1.23456], 7)).to eq([-0.00125, 1.23456])
      end

      it 'rounds NArrays' do
        expect(MB::M.round(Numo::SFloat[-0.00125, 1.23456], 1)).to eq([0, 1.2])
        expect(MB::M.round(Numo::SFloat[-0.00125, 1.23456], 4)).to eq([-0.0013, 1.2346])
        expect(MB::M.round(Numo::SFloat[-0.00125, 1.23456], 7)).to eq([-0.00125, 1.23456])
      end
    end

    context 'with negative figs' do
      it 'rounds individual numbers' do
        expect(MB::M.round(12345.6789, -1)).to eq(12350)
        expect(MB::M.round(12345.6789, -4)).to eq(10000)
        expect(MB::M.round(-543, -1)).to eq(-540)
        expect(MB::M.round(-543, -4)).to eq(0)
      end

      it 'rounds Arrays' do
        expect(MB::M.round([12345.6789, -543], -1)).to eq([12350, -540])
        expect(MB::M.round([12345.6789, -543], -4)).to eq([10000, 0])
      end

      it 'rounds NArrays' do
        expect(MB::M.round(Numo::SFloat[12345.6789, -543], -1)).to eq(Numo::SFloat[12350, -540])
        expect(MB::M.round(Numo::SFloat[12345.6789, -543], -4)).to eq(Numo::SFloat[10000, 0])
      end
    end

    context 'with fractional figs' do
      it 'truncates figs to an integer' do
        expect(MB::M.round(12345.6789, 2.4)).to eq(12345.68)
        expect(MB::M.round(12345.6789, 2.9)).to eq(12345.68)
        expect(MB::M.round([12345.6789], 2.4)).to eq([12345.68])
        expect(MB::M.round([12345.6789], 2.9)).to eq([12345.68])
        expect(MB::M.round(Numo::DFloat[12345.6789], 2.4)).to eq([12345.68])
        expect(MB::M.round(Numo::DFloat[12345.6789], 2.9)).to eq([12345.68])
      end
    end
  end

  describe '.quadratic_roots' do
    it 'can find roots of an equation with two real roots' do
      expect(MB::M.quadratic_roots(1, 0, -4).sort).to eq([-2, 2])
    end

    it 'can find roots of an equation with one real root' do
      expect(MB::M.quadratic_roots(1, -2, 1).sort).to eq([1, 1])
    end

    it 'can find complex roots of an equation with no real roots' do
      expect(MB::M.quadratic_roots(1, 0, 1).sort_by { |r| [r.real, r.imag] }).to eq([0-1i, 0+1i])
    end
  end

  describe '.parse_complex' do
    tests = {
      '+1' => 1.0,
      '-1' => -1.0,
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
    }

    tests.each do |k, v|
      it "parses #{k.inspect} correctly" do
        expect(MB::M.round(MB::M.parse_complex(k), 10)).to eq(MB::M.round(v, 10))
      end
    end
  end
end
