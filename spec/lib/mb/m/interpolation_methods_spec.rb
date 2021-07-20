RSpec.describe(MB::M::InterpolationMethods) do
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
      it 'can map across multiple blend values' do
        expect(MB::M.interp(-1, 1, [0, 0.5, 1])).to eq([-1, 0, 1])
      end

      it 'can map across a Numo::NArray for blend values' do
        expect(MB::M.interp(-1, 1, Numo::SFloat[0, 0.5, 1])).to eq(Numo::SFloat[-1, 0, 1])
      end

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
      it 'can map across multiple blend values' do
        expect(MB::M.interp([-1, -1], [1, 2], [0, 0.5, 1])).to eq([[-1, -1], [0, 0.5], [1, 2]])
      end

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
      it 'can map across multiple blend values' do
        expected = [Numo::SFloat[-1, -1], Numo::SFloat[0, 0.5], Numo::SFloat[1, 2]]
        expect(MB::M.interp(Numo::SFloat[-1, -1], Numo::SFloat[1, 2], [0, 0.5, 1])).to eq(expected)
      end

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

  describe '#catmull_rom' do
    it 'can interpolate numeric values' do
      expect(MB::M.catmull_rom(1, 5, 15, 3, 0.5)).to be_between(10, 12)
    end

    it 'interpolates numeric values in monotonically increasing order' do
      result = Numo::SFloat.linspace(0, 1, 10).map { |v|
        MB::M.catmull_rom(1, 5, 15, 3, v)
      }

      expect(result.to_a.sort).to eq(result.to_a)
      expect(result.diff.min).to be > 0
    end

    it 'can interpolate arrays of length 2' do
      result = MB::M.catmull_rom([1, 5], [3, 3], [-2.5, 4.5], [-1, 4], 0.25, 0.1)
      expect(result[0]).to be_between(-2.6, 2.9)
      expect(result[1]).to be_between(3.1, 4.4)
    end

    it 'can interpolate arrays of length 3' do
      result = MB::M.catmull_rom([1, 5, 1], [3, 3, 3], [-2.5, 4.5, -2.5], [-1, 4, -1], 0.25, 0.1)
      expect(result[0]).to be_between(-2.6, 2.9)
      expect(result[1]).to be_between(3.1, 4.4)
      expect(result[2]).to be_between(-2.6, 2.9)
    end

    it 'can interpolate narrays of length 4' do
      result = MB::M.catmull_rom(Numo::SFloat[1, 5, 1, 5], Numo::SFloat[3, 3, 3, 3], Numo::SFloat[-2.5, 4.5, -2.5, 4.5], Numo::SFloat[-1, 4, -1, 4], 0.25, 0.1)
      expect(result[0]).to be_between(-2.6, 2.9)
      expect(result[1]).to be_between(3.1, 4.4)
      expect(result[2]).to be_between(-2.6, 2.9)
      expect(result[3]).to be_between(3.1, 4.4)
    end

    it 'can interpolate narrays of length 5' do
      result = MB::M.catmull_rom(Numo::SFloat[1, 5, 1, 5, 1], Numo::SFloat[3, 3, 3, 3, 3], Numo::SFloat[-2.5, 4.5, -2.5, 4.5, -2.5], Numo::SFloat[-1, 4, -1, 4, -1], 0.25, 0.1)
      expect(result[0]).to be_between(-2.6, 2.9)
      expect(result[1]).to be_between(3.1, 4.4)
      expect(result[2]).to be_between(-2.6, 2.9)
      expect(result[3]).to be_between(3.1, 4.4)
      expect(result[4]).to be_between(-2.6, 2.9)
    end

    it 'does something with alpha' do
      # TODO: test this actually does what it should
      zero = MB::M.catmull_rom(1, 5, 3, 4, 0.5, 0)
      half = MB::M.catmull_rom(1, 5, 3, 4, 0.5, 0.5)
      one = MB::M.catmull_rom(1, 5, 3, 4, 0.5, 1)
      expect(zero).not_to eq(half)
      expect(zero).not_to eq(one)
      expect(half).not_to eq(one)
    end

    it 'can interpolate complex numbers' do
      result = MB::M.catmull_rom(1-1i, 2-2i, 3-3i, 4-4i, 0.5)
      expect(result.real).to be_between(2.4, 2.6)
      expect(result.imag).to be_between(-2.6, -2.4)
    end
  end
end
