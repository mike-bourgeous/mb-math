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
  end
end
