RSpec.describe(MB::M::PrecisionMethods) do
  describe '#sigfigs' do
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

  describe '#round' do
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

      it 'rounds Hashes' do
        expect(MB::M.round({a: 1.2, b: [2.1, 3.9]})).to eq({a: 1, b: [2, 4]})
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

      it 'rounds Hashes' do
        expect(MB::M.round({a: 0.00125, b: [1.23456, 6.11111111]}, 4)).to eq({a: 0.0013, b: [1.2346, 6.1111]})
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

      it 'rounds Hashes' do
        expect(MB::M.round({a: 12345.67, b: [-543, 543]}, -2)).to eq({a: 12300, b: [-500, 500]})
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

    context 'with complex numbers' do
      it 'removes imaginary parts if they become zero' do
        result = MB::M.round(1+0.001i)
        expect(result).to eq(1)
        expect(result).not_to be_a(Complex)
      end

      it 'rounds real and imaginary parts separately' do
        expect(MB::M.round(1.23456-0.00789i, 3)).to eq(1.235-0.008i)
      end

      it 'rounds Complex numbers within a Hash' do
        expect(MB::M.round({a: [1.25i, 1.75i], b: 3.95 + 3.0005i}, 1)).to eq({a: [1.3i, 1.8i], b: 4+3i})
      end
    end
  end

  describe '#round_to' do
    context 'with an Integer multiple' do
      it 'rounds numbers to nearest multiples' do
        expect(MB::M.round_to(15, 30)).to eq(30)
        expect(MB::M.round_to(14.999, 30)).to eq(0)
        expect(MB::M.round_to(-14.999, 30)).to eq(0)
        expect(MB::M.round_to(-15, 30)).to eq(-30)
      end

      it 'behaves the same with a negative multiple' do
        expect(MB::M.round_to(-32, 3)).to eq(-33)
        expect(MB::M.round_to(-32, -3)).to eq(-33)
      end

      it 'can round with an offset' do
        expect(MB::M.round_to(16.5, 30, 1.5)).to eq(31.5)
        expect(MB::M.round_to(16.499, 30, 1.5)).to eq(1.5)
        expect(MB::M.round_to(-13.499, 30, 1.5)).to eq(1.5)
        expect(MB::M.round_to(-13.5, 30, 1.5)).to eq(-28.5)
      end
    end

    context 'with a fractional multiple' do
      it 'rounds to multiples of the fraction' do
        expect(MB::M.round_to(2.124, 0.25)).to eq(2)
        expect(MB::M.round_to(2.125, 0.25)).to eq(2.25)
        expect(MB::M.round_to(-2.3, 0.25)).to eq(-2.25)
      end
    end

    context 'with a Numo::NArray' do
      it 'rounds each value to the multiple' do
        expect(MB::M.round_to(Numo::SFloat[0, 0.5, 2, 3, 4], 0.75)).to eq(Numo::SFloat[0, 0.75, 2.25, 3, 3.75])
      end
    end

    context 'with an Array' do
      it 'rounds each value to the multiple' do
        expect(MB::M.round_to([0, 0.5, 2, 3, 4], 0.75)).to eq([0, 0.75, 2.25, 3, 3.75])
      end
    end

    it 'can round Complex values' do
      expect(MB::M.round_to(1.32+3.2i, 1+2i)).to eq(2+4i)
    end
  end

  describe '#sigformat' do
    tests = {
      0 => '0',
      5 => '5',
      -5 => '-5',
      -15 => '-15',
      99 => '99',
      -99.99 => '-100',
      99.999 => '100',
      [99.999, 4] => '100',
      [99.999, 5] => '99.999',
      123 => '123',
      [123, 1] => '100',
      [123, 2] => '120',
      [123.432, 2] => '120',
      [123.432, 3] => '123',
      [123.432, 4] => '123.4',
      [123.432, 5] => '123.43',
      1234 => '1.23k',
      [12345, 4] => '1.235k',
      12345 => '12.3k',
      [12345, 4] => '12.35k',
      1234567 => '1.23M',
      [1234567, 1] => '1M',
      [1234567, 2] => '1.2M',
      [1234567, 3] => '1.23M',
      [1234567, 4] => '1.235M',
      [1234567, 5] => '1.2346M',
      [12345678900, 2] => '12G',
      0.12345 => '123m',
      0.0001234 => "123\u00b5",
      -0.001 => '-1m',
      0.1 => '100m',
      -0.01 => '-10m',
      -0.0012345 => '-1.23m',
      [-0.0012345, 4] => '-1.235m',
      [-0.012345, 1] => '-10m',
      [-0.012345, 2] => '-12m',
      [-0.012345, 4] => '-12.35m',
      [-0.012345, 6] => '-12.3450m',
    }

    tests.each do |input, output|
      it "formats #{input} correctly as #{output.inspect}" do
        expect(MB::M.sigformat(*input)).to eq(output)
      end
    end

    it 'includes the decimals if force_decimal is true' do
      expect(MB::M.sigformat(0, force_decimal: true)).to eq('0.00')
      expect(MB::M.sigformat(4, force_decimal: true)).to eq('4.00')
      expect(MB::M.sigformat(4000, force_decimal: true)).to eq('4.00k')

      expect(MB::M.sigformat(4, 4, force_decimal: true)).to eq('4.000')
      expect(MB::M.sigformat(40, 4, force_decimal: true)).to eq('40.00')
      expect(MB::M.sigformat(400, 4, force_decimal: true)).to eq('400.0')
      expect(MB::M.sigformat(4000, 4, force_decimal: true)).to eq('4.000k')
      expect(MB::M.sigformat(40000, 4, force_decimal: true)).to eq('40.00k')
    end

    it 'never includes decimals if force_decimal is false' do
      expect(MB::M.sigformat(1.0, 4, force_decimal: false)).to eq('1')
      expect(MB::M.sigformat(1000.0, 4, force_decimal: false)).to eq('1k')
      expect(MB::M.sigformat(0.1001, 4, force_decimal: false)).to eq('100m')
      expect(MB::M.sigformat(123987654, 4, force_decimal: false)).to eq('124M')
    end

    it 'accepts a number of decimals for force_decimal' do
      expect(MB::M.sigformat(1.0, 4, force_decimal: 1)).to eq('1.0')
      expect(MB::M.sigformat(1000, 4, force_decimal: 1)).to eq('1.0k')
      expect(MB::M.sigformat(1000, 1, force_decimal: 3)).to eq('1.000k')
      expect(MB::M.sigformat(0.01234, 2, force_decimal: 3)).to eq('12.000m')
      expect(MB::M.sigformat(0.0123456, 4, force_decimal: 3)).to eq('12.350m')
      expect(MB::M.sigformat(0.0123456, 7, force_decimal: 3)).to eq('12.346m')
      expect(MB::M.sigformat(0.0123456, 7, force_decimal: 4)).to eq('12.3456m')
    end

    it 'honors force_sign for displayed integers' do
      expect(MB::M.sigformat(0, force_sign: true)).to eq('+0')
      expect(MB::M.sigformat(0.0 * -1.0, force_sign: true)).to eq('-0')
      expect(MB::M.sigformat(-2, force_sign: true)).to eq('-2')
      expect(MB::M.sigformat(1, force_sign: true)).to eq('+1')
      expect(MB::M.sigformat(0.001, force_sign: true)).to eq('+1m')
      expect(MB::M.sigformat(-0.001, force_sign: true)).to eq('-1m')
    end

    it 'honors force_sign for displayed decimals' do
      expect(MB::M.sigformat(0, force_decimal: true, force_sign: true)).to eq('+0.00')
      expect(MB::M.sigformat(0, 4, force_decimal: true, force_sign: true)).to eq('+0.000')
      expect(MB::M.sigformat(0.0 * -1.0, force_decimal: true, force_sign: true)).to eq('-0.00')
      expect(MB::M.sigformat(-2, force_decimal: true, force_sign: true)).to eq('-2.00')
      expect(MB::M.sigformat(1, force_decimal: true, force_sign: true)).to eq('+1.00')
      expect(MB::M.sigformat(0.001, force_decimal: true, force_sign: true)).to eq('+1.00m')
      expect(MB::M.sigformat(-0.001, force_decimal: true, force_sign: true)).to eq('-1.00m')

      expect(MB::M.sigformat(-0.0125, force_decimal: true, force_sign: true)).to eq('-12.5m')
      expect(MB::M.sigformat(-0.125, force_decimal: true, force_sign: true)).to eq('-125.0m')
      expect(MB::M.sigformat(0.0125, force_decimal: true, force_sign: true)).to eq('+12.5m')
      expect(MB::M.sigformat(0.125, force_decimal: true, force_sign: true)).to eq('+125.0m')
    end
  end
end
