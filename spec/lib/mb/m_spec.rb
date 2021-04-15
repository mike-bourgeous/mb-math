RSpec.describe(MB::M) do
  describe '.smoothstep' do
    it 'returns reasonable values' do
      expect(MB::M.smoothstep(0)).to eq(0)
      expect(MB::M.smoothstep(1)).to eq(1)
      expect(MB::M.smoothstep(0.5)).to eq(0.5)
      expect(MB::M.smoothstep(0.1)).not_to eq(0.1)
      expect(MB::M.smoothstep(0.9)).not_to eq(0.9)
    end
  end

  describe '.smootherstep' do
    it 'returns reasonable values' do
      expect(MB::M.smootherstep(0)).to eq(0)
      expect(MB::M.smootherstep(1)).to eq(1)
      expect(MB::M.smootherstep(0.5)).to eq(0.5)
      expect(MB::M.smootherstep(0.1)).not_to eq(0.1)
      expect(MB::M.smootherstep(0.9)).not_to eq(0.9)
    end
  end

  describe '.interp' do
    context 'with scalar values' do
      it 'interpolates correctly' do
        expect(MB::M.interp(-1, 1, 0)).to eq(-1)
        expect(MB::M.interp(-1, 1, 0.25)).to eq(-0.5)
        expect(MB::M.interp(-1, 1, 0.5)).to eq(0)
        expect(MB::M.interp(-1, 1, 0.75)).to eq(0.5)
        expect(MB::M.interp(-1, 1, 1)).to eq(1)

        expect(MB::M.interp(3, -1, 0)).to eq(3)
        expect(MB::M.interp(3, -1, 0.5)).to eq(1)
        expect(MB::M.interp(3, -1, 1)).to eq(-1)
      end

      it 'interpolates equal values' do
        expect(MB::M.interp(3, 3, 0)).to eq(3)
        expect(MB::M.interp(3, 3, 0.5)).to eq(3)
        expect(MB::M.interp(3, 3, 1)).to eq(3)
      end

      it 'extrapolates values' do
        expect(MB::M.interp(-1, 1, -1)).to eq(-3)
        expect(MB::M.interp(-1, 1, 2)).to eq(3)
      end

      it 'can use a different interpolator' do
        expect(MB::M.interp(-1, 1, 0.25, func: ->(_){0})).to eq(-1)
        expect(MB::M.interp(-1, 1, 0.25, func: ->(_){1})).to eq(1)
        expect(MB::M.interp(-1, 1, 0.25, func: ->(x){ x })).to eq(-0.5)
        expect(MB::M.interp(-1, 1, 0.25, func: ->(x){ x * 2 })).to eq(0)
      end
    end

    context 'with arrays' do
      it 'raises an error if arrays have different sizes' do
        expect { MB::M.interp([1, 2], [1, 2, 3], 0.5) }.to raise_error(/same length/)
      end

      it 'interpolates two-element arrays' do
        a = [-1, 0]
        b = [1, 4]

        expect(MB::M.interp(a, b, 0)).to eq([-1, 0])
        expect(MB::M.interp(a, b, 0.5)).to eq([0, 2])
        expect(MB::M.interp(a, b, 1)).to eq([1, 4])
      end

      it 'interpolates three-element arrays' do
        a = [-1, 0, 2]
        b = [1, 4, 0]

        expect(MB::M.interp(a, b, 0)).to eq([-1, 0, 2])
        expect(MB::M.interp(a, b, 0.5)).to eq([0, 2, 1])
        expect(MB::M.interp(a, b, 1)).to eq([1, 4, 0])
      end

      it 'interpolates nested arrays' do
        a = [
          [0, 1],
          [1, 0],
        ]

        b = [
          [1, -1],
          [0, 2],
        ]

        expect(MB::M.interp(a, b, 0)).to eq([[0, 1], [1, 0]])
        expect(MB::M.interp(a, b, 0.5)).to eq([[0.5, 0], [0.5, 1]])
        expect(MB::M.interp(a, b, 1)).to eq([[1, -1], [0, 2]])
      end

      it 'can use a different interpolator' do
        a = [-1, 0, 2]
        b = [1, 4, 0]

        expect(MB::M.interp(a, b, 0.0, func: ->(x) { (0.5 - x).abs })).to eq([0, 2, 1])
        expect(MB::M.interp(a, b, 0.5, func: ->(x) { (0.5 - x).abs })).to eq([-1, 0, 2])
        expect(MB::M.interp(a, b, 1.0, func: ->(x) { (0.5 - x).abs })).to eq([0, 2, 1])
      end
    end

    context 'with a Numo::NArray' do
      it 'interpolates between scalar and NArray' do
        a = Numo::SFloat[1, 2, 3]

        expect(MB::M.interp(a, 0, 0)).to eq(Numo::SFloat[1, 2, 3])
        expect(MB::M.interp(a, 0, 0.5)).to eq(Numo::SFloat[0.5, 1, 1.5])
        expect(MB::M.interp(a, 0, 1)).to eq(Numo::SFloat[0, 0, 0])

        expect(MB::M.interp(0, a, 0)).to eq(Numo::SFloat[0, 0, 0])
        expect(MB::M.interp(0, a, 0.5)).to eq(Numo::SFloat[0.5, 1, 1.5])
        expect(MB::M.interp(0, a, 1)).to eq(Numo::SFloat[1, 2, 3])
      end

      it 'interpolates NArrays' do
        a = Numo::SFloat[1, 2, 3]
        b = Numo::SFloat[0, -2, -3]

        expect(MB::M.interp(a, b, 0)).to eq(Numo::SFloat[1, 2, 3])
        expect(MB::M.interp(a, b, 0.5)).to eq(Numo::SFloat[0.5, 0, 0])
        expect(MB::M.interp(a, b, 1)).to eq(Numo::SFloat[0, -2, -3])
      end
    end

    context 'with a Hash' do
      it 'interpolates numeric hash keys' do
        a = {a: 1, b: 2, c: 3}
        b = {a: 2, b: 3, c: 4}

        expect(MB::M.interp(a, b, 0)).to eq(a)
        expect(MB::M.interp(a, b, 0.5)).to eq({a: 1.5, b: 2.5, c: 3.5})
        expect(MB::M.interp(a, b, 1)).to eq(b)
      end

      it 'interpolates nested hashes and arrays' do
        a = {a: {x: 1, y: 2, z: [3, 4]}, b: 5, c: 6}
        b = {a: {x: 2, y: 3, z: [4, 5]}, b: 6, c: 7}

        expect(MB::M.interp(a, b, 0)).to eq(a)
        expect(MB::M.interp(a, b, 0.5)).to eq({a: {x: 1.5, y: 2.5, z: [3.5, 4.5]}, b: 5.5, c: 6.5})
        expect(MB::M.interp(a, b, 1)).to eq(b)
      end
    end
  end

  describe '.scale' do
    it 'acceps reverse ranges' do
      expect(MB::M.scale(0.5, -1.0..1.0, 1.0..-1.0)).to eq(-0.5)
      expect(MB::M.scale(0.5, 1.0..-1.0, -1.0..1.0)).to eq(-0.5)
      expect(MB::M.scale(0.5, 1.0..-1.0, 2.0..1.0)).to eq(1.75)
    end

    it 'can scale an NArray' do
      expect(MB::M.scale(Numo::SFloat[1, 2, 3], 0.0..1.0, 0.0..2.0)).to eq(Numo::SFloat[2, 4, 6])
    end
  end

  describe '.clamp' do
    it 'passes through valid values' do
      expect(MB::M.clamp(0.5, 0, 1)).to eq(0.5)
    end

    it 'returns max for high values' do
      expect(MB::M.clamp(1.5, 0, 1)).to eq(1)
    end

    it 'returns min for low values' do
      expect(MB::M.clamp(-1, 0, 1)).to eq(0)
    end

    it 'passes through high values but not low values if max is nil' do
      expect(MB::M.clamp(Float::MAX, 0, nil)).to eq(Float::MAX)
      expect(MB::M.clamp(-Float::MAX, 0, nil)).to eq(0)
      expect(MB::M.clamp(1, 0, nil)).to eq(1)
      expect(MB::M.clamp(-1, 0, nil)).to eq(0)
    end

    it 'passes through low values but not high values if min is nil' do
      expect(MB::M.clamp(Float::MAX, nil, 1)).to eq(1)
      expect(MB::M.clamp(-Float::MAX, nil, 1)).to eq(-Float::MAX)
      expect(MB::M.clamp(0.1, nil, 1)).to eq(0.1)
      expect(MB::M.clamp(1.1, nil, 1)).to eq(1)
    end

    it 'can clamp an NArray' do
      expect(MB::M.clamp(Numo::SFloat[-3, -2, -1, 0, 1, 2, 3], -1, 1)).to eq(Numo::SFloat[-1, -1, -1, 0, 1, 1, 1])
    end

    it 'converts ints to to floats if clamping an integer narray to a float range' do
      expect(MB::M.clamp(Numo::Int32[-3, -2, -1, 0, 1, 2, 3], -1.5, 1.5)).to eq(Numo::SFloat[-1.5, -1.5, -1, 0, 1, 1.5, 1.5])
    end
  end

  describe '.safe_power' do
    it 'scales positive values' do
      expect(MB::M.safe_power(0.25, 0.5)).to eq(0.5)
    end

    it 'scales negative values' do
      expect(MB::M.safe_power(-0.25, 0.5)).to eq(-0.5)
    end
  end

  describe '.array_to_narray' do
    it 'converts a 1D array' do
      expect(MB::M.array_to_narray([1,2,3])).to eq(Numo::NArray[1,2,3])
    end

    it 'converts a 2D array' do
      expect(MB::M.array_to_narray([[1,2],[3,4]])).to eq(Numo::NArray[[1,2],[3,4]])
    end

    it 'converts a 3D array' do
      expect(MB::M.array_to_narray([[[1,2],[3,4]],[[5,6],[7,8]]])).to eq(Numo::NArray[[[1,2],[3,4]],[[5,6],[7,8]]])
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
end
