RSpec.describe(MB::M::ArrayMethods, :aggregate_failures) do
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

  describe '.with_inplace' do
    it 'yields a non-narray if inplace is false' do
      result = nil
      MB::M.with_inplace(4.0, false) do |v|
        result = v
      end
      expect(result).to eq(4.0)
    end

    it 'raises an error with a non-narray if inplace is true' do
      expect { MB::M.with_inplace(4.0, true) }.to raise_error(ArgumentError, /inplace.*false/i)
    end

    pending 'non-inplace narray with inplace false'
    pending 'non-inplace narray with inplace true'
    pending 'inplace narray with inplace false'
    pending 'inplace narray with inplace true'
  end

  describe '.append_shift' do
    let(:base) { Numo::SFloat[1,2,3,4,5].freeze }

    it 'leaves the array unmodified and returns an empty array for a zero-length append' do
      data = base.copy
      expect(MB::M.append_shift(data, Numo::SFloat[])).to eq(Numo::SFloat[])
      expect(data).to eq(base)
    end

    it 'returns the original array and entirely replaces its contents for an equal-length append' do
      data = base.copy
      append = Numo::SFloat[5,4,3,2,1].freeze
      result = MB::M.append_shift(data, append)
      expect(result).to eq(base)
      expect(data).to eq(append)
    end

    it 'returns the expected shifted values for a partial append' do
      data = base.copy
      append = Numo::SFloat[6,7].freeze
      expect(MB::M.append_shift(data, append)).to eq(Numo::SFloat[1,2])
      expect(MB::M.append_shift(data, append)).to eq(Numo::SFloat[3,4])

      MB::M.append_shift(data, append)
      expect(data).to eq(Numo::SFloat[7,6,7,6,7])
    end
  end

  describe '.circular_read' do
    context 'without a target' do
      it 'can read without wrapping' do
        result = MB::M.circular_read(Numo::SFloat[1, 2, 3, 4, 5], 0, 4)
        expect(result).to eq(Numo::SFloat[1, 2, 3, 4])
      end

      it 'can read with wrapping' do
        result = MB::M.circular_read(Numo::SFloat[1, 2, 3, 4, 5], 3, 4)
        expect(result).to eq(Numo::SFloat[4, 5, 1, 2])
      end

      it 'can read from a negative offset' do
        result = MB::M.circular_read(Numo::SFloat[1, 2, 3, 4, 5], -3, 4)
        expect(result).to eq(Numo::SFloat[3, 4, 5, 1])
      end
    end

    context 'with a target' do
      it 'can read without wrapping' do
        target = Numo::SFloat.zeros(4)
        result = MB::M.circular_read(Numo::SFloat[1, 2, 3, 4, 5], 0, 4, target: target)
        expect(target).to equal(result)
        expect(target).to eq(Numo::SFloat[1, 2, 3, 4])
      end

      it 'can read with wrapping' do
        target = Numo::SFloat.zeros(4)
        result = MB::M.circular_read(Numo::SFloat[1, 2, 3, 4, 5], 3, 4, target: target)
        expect(target).to equal(result)
        expect(target).to eq(Numo::SFloat[4, 5, 1, 2])
      end

      it 'can read from a negative offset' do
        target = Numo::SFloat.zeros(4)
        result = MB::M.circular_read(Numo::SFloat[1, 2, 3, 4, 5], -3, 4, target: target)
        expect(target).to equal(result)
        expect(target).to eq(Numo::SFloat[3, 4, 5, 1])
      end

      it 'can write into an offset view of a base array' do
        target = Numo::SComplex.zeros(7)
        result = MB::M.circular_read(Numo::SFloat[1,2,3,4,5], 4, 3, target: target[3..-1])
        expect(result).to eq(Numo::SComplex[5, 1, 2, 0])
        expect(target).to eq(Numo::SComplex[0, 0, 0, 5, 1, 2, 0])
      end
    end
  end

  describe '.circular_write' do
    it 'raises an error if the target buffer is too small' do
      s = Numo::SFloat[1, 2, 3]
      t = Numo::SFloat.zeros(2)
      expect { MB::M.circular_write(t, s, 0) }.to raise_error(ArgumentError, /large/)
    end

    it 'raises an error if the write offset is out of bounds of the target' do
      s = Numo::SFloat[1]
      t = Numo::SFloat.zeros(2)
      expect { MB::M.circular_write(t, s, 2) }.to raise_error(IndexError, /bounds/)
    end

    it 'returns the target buffer' do
      s = Numo::SFloat.ones(7)
      t = Numo::SFloat.zeros(7)

      r = MB::M.circular_write(t, s, 0)
      expect(r).to equal(t)
      expect(r).not_to equal(s)
    end

    it 'can write into an equal sized buffer with no offset' do
      s = Numo::SFloat.ones(7)
      t = Numo::SFloat.zeros(7)

      MB::M.circular_write(t, s, 0)
      expect(t).to eq(s)
    end

    it 'can write into an equal sized buffer with an offset' do
      s = Numo::Int32[1, 2, 3, 4]
      t = Numo::Int32.zeros(4)

      MB::M.circular_write(t, s, 1)
      expect(t).to eq(Numo::Int32[4, 1, 2, 3])

      MB::M.circular_write(t, s, 2)
      expect(t).to eq(Numo::Int32[3, 4, 1, 2])

      MB::M.circular_write(t, s, 3)
      expect(t).to eq(Numo::Int32[2, 3, 4, 1])
    end

    it 'can write float values into a complex buffer' do
      s = Numo::SFloat[1, 2, 3]
      t = Numo::DComplex.zeros(6)

      MB::M.circular_write(t, s, 4)
      expect(t).to eq(Numo::DComplex[3, 0, 0, 0, 1, 2])
    end

    it 'can write into a larger buffer without wrapping' do
      s = Numo::DComplex.ones(2)
      t = Numo::DComplex.zeros(3)

      MB::M.circular_write(t, s, 1)
      expect(t).to eq(Numo::DComplex[0, 1, 1])

      t.fill(2)
      MB::M.circular_write(t, s, 0)
      expect(t).to eq(Numo::DComplex[1, 1, 2])
    end

    it 'can write into a larger buffer with wrapping' do
      s = Numo::RObject[false, true, Array]
      t = Numo::RObject[nil, nil, nil, nil, nil]

      MB::M.circular_write(t, s, 4)
      expect(t).to eq(Numo::RObject[true, Array, nil, nil, false])
    end

    it 'can use a negative offset' do
      s = Numo::UInt32[1, 2, 3]
      t = Numo::Int64.zeros(6)

      MB::M.circular_write(t, s, -1)
      expect(t).to eq(Numo::Int64[2, 3, 0, 0, 0, 1])

      t.fill(0)
      MB::M.circular_write(t, s, -3)
      expect(t).to eq(Numo::Int64[0, 0, 0, 1, 2, 3])
    end
  end

  describe '.pad' do
    it 'can right-pad with a single value' do
      expect(MB::M.pad(Numo::SFloat[1], 3, value: 2, alignment: 0)).to eq(Numo::SFloat[1, 2, 2])
    end

    it 'can left-pad with a single value' do
      expect(MB::M.pad(Numo::SFloat[1], 3, value: 2, alignment: 1)).to eq(Numo::SFloat[2, 2, 1])
    end

    it 'can center with a single value' do
      expect(MB::M.pad(Numo::SFloat[1], 3, value: 2, alignment: 0.5)).to eq(Numo::SFloat[2, 1, 2])
      expect(MB::M.pad(Numo::SFloat[1], 5, value: 2, alignment: 0.5)).to eq(Numo::SFloat[2, 2, 1, 2, 2])
    end

    it 'can bias alignment left' do
      expect(MB::M.pad(Numo::SFloat[1], 5, before: 0, after: 2, alignment: 0.25)).to eq(Numo::SFloat[0, 1, 2, 2, 2])
    end

    it 'can bias alignment right' do
      expect(MB::M.pad(Numo::SFloat[1], 5, before: 0, after: 2, alignment: 0.75)).to eq(Numo::SFloat[0, 0, 0, 1, 2])
    end

    it 'can left-pad an empty narray' do
      expect(MB::M.pad(Numo::SFloat[], 4, before: 1, after: 2, alignment: 0)).to eq(Numo::SFloat[2, 2, 2, 2])
    end

    it 'can left-biased-pad an empty narray' do
      expect(MB::M.pad(Numo::SFloat[], 4, before: 1, after: 2, alignment: 0.25)).to eq(Numo::SFloat[1, 2, 2, 2])
    end

    it 'can center-pad an empty narray' do
      expect(MB::M.pad(Numo::SFloat[], 2, before: 1, after: 2, alignment: 0.5)).to eq(Numo::SFloat[1, 2])
    end

    it 'can right-biased-pad an empty narray' do
      expect(MB::M.pad(Numo::SFloat[], 4, before: 1, after: 2, alignment: 0.75)).to eq(Numo::SFloat[1, 1, 1, 2])
    end

    it 'can right-pad an empty narray' do
      expect(MB::M.pad(Numo::SFloat[], 4, before: 1, after: 2, alignment: 1)).to eq(Numo::SFloat[1, 1, 1, 1])
    end

    it 'leaves an empty narray alone when the target size is zero' do
      result = MB::M.pad(Numo::SFloat[], 0, before: 1, after: 2, alignment: 0.5)
      expect(result).to be_a(Numo::SFloat)
      expect(result.length).to eq(0)
    end

    it 'can pad a complex narray' do
      result = MB::M.pad(Numo::DComplex[1+0i, 0+1i], 4, before: 2, after: -2, alignment: 0.5)
      expect(result).to be_a(Numo::DComplex)
      expect(result).to eq(Numo::DComplex[2, 1+0i, 0+1i, -2])
    end

    fromto = [
      [3, 4],
      [3, 5],
      [17, 31],
      [17, 32],
      [1000, 563567],
    ]

    alignments = [0.0, 0.25, (1.0 / 3.0), 0.5, (5.0 / 7.0), 0.9, 1.0]

    fromto.each do |(from_size, to_size)|
      alignments.each do |align|
        it "results in the correct length for #{from_size}->#{to_size}@#{align.round(5)}" do
          base = Numo::SFloat.zeros(from_size)
          expect(MB::M.pad(base, to_size, alignment: align).length).to eq(to_size)
        end
      end
    end

    context 'when a block is given' do
      it 'returns the original data if the block does not modify the padded data' do
        data = Numo::SFloat.linspace(-1, -2, 100)

        padded = nil
        result = MB::M.pad(data, 150, before: 1, after: 2, alignment: 0.25) do |p| padded = p end
        expect(result).to eq(data)
        expect(padded.length).to eq(150)
      end

      it 'returns data as modified by the block' do
        data = Numo::SFloat.linspace(-1, -2, 127)
        result = MB::M.pad(data, 139, before: 2, after: 1, alignment: 0.37) do |p| p * 2 end
        expect(result).to eq(data * 2)
      end

      it 'still yields to the block if the data is already long enough' do
        data = Numo::SFloat[1, 2, 3]
        padded = nil
        result = MB::M.pad(data, 3, value: 0.5) do |p| padded = p end
        expect(result).to eq(data)
        expect(padded).to eq(data)
      end

      it 'still yields to the block if the data is already longer' do
        data = Numo::SFloat[1, 2, 3]
        padded = nil
        result = MB::M.pad(data, 0, value: 0.5) do |p| padded = p end
        expect(result).to eq(data)
        expect(padded).to eq(data)
      end
    end
  end

  describe '.zpad' do
    it 'defaults to right-pad' do
      expect(MB::M.zpad(Numo::SFloat[1], 2)).to eq(Numo::SFloat[1, 0])
    end

    it 'can pad an empty narray' do
      expect(MB::M.zpad(Numo::SFloat[], 2)).to eq(Numo::SFloat[0, 0])
    end

    it 'can pad a Ruby Array' do
      expect(MB::M.zpad([1,2,3], 5, alignment: 0)).to eq([1, 2, 3, 0, 0])
      expect(MB::M.zpad([1,2,3], 5, alignment: 1)).to eq([0, 0, 1, 2, 3])
    end

    context 'when a block is given' do
      it 'returns original length data as modified by the block' do
        expect(MB::M.zpad(Numo::SFloat.ones(3), 5) { |p| p + 1 }).to eq(Numo::SFloat.ones(3) * 2)
      end

      it 'works when the data is already long enough' do
        expect(MB::M.zpad(Numo::SFloat.ones(3), 3) { |p| Numo::SFloat[4, 3, 2] }).to eq(Numo::SFloat[4, 3, 2])
      end

      it 'works when the data is already longer' do
        expect(MB::M.zpad(Numo::SFloat.ones(3), 1) { |p| Numo::SFloat[1, 2, 3] }).to eq(Numo::SFloat[1, 2, 3])
      end
    end
  end

  describe '.opad' do
    it 'defaults to right-pad' do
      expect(MB::M.opad(Numo::SFloat[2], 2)).to eq(Numo::SFloat[2, 1])
    end

    it 'can pad an empty narray' do
      expect(MB::M.opad(Numo::SFloat[], 2)).to eq(Numo::SFloat[1, 1])
    end

    context 'when a block is given' do
      it 'returns original length data as modified by the block' do
        expect(MB::M.zpad(Numo::SFloat.zeros(3), 5) { |p| p + 3 }).to eq(Numo::SFloat.ones(3) * 3)
      end

      it 'works when the data is already long enough' do
        expect(MB::M.zpad(Numo::SFloat.zeros(3), 3) { |p| Numo::SFloat.ones(3) }).to eq(Numo::SFloat.ones(3))
      end

      it 'works when the data is already longer' do
        expect(MB::M.zpad(Numo::SFloat.zeros(3), 1) { |p| Numo::SFloat[1, 2, 3] }).to eq(Numo::SFloat[1, 2, 3])
      end
    end
  end

  describe '#ltrim' do
    context 'with Numo::NArray' do
      let(:zero) { Numo::SFloat[0, 0, 0, 1, 2, 3] }
      let(:one) { Numo::SFloat[1, 1, 1, 2, 3, 4] }

      it 'returns an empty array for an empty array' do
        expect(MB::M.ltrim(Numo::SFloat[])).to eq(Numo::SFloat[])
      end

      it 'accepts a value parameter' do
        expect(MB::M.ltrim(zero, 1)).to eq(zero)
        expect(MB::M.ltrim(zero, 0)).to eq(Numo::SFloat[1, 2, 3])

        expect(MB::M.ltrim(one, 0)).to eq(one)
        expect(MB::M.ltrim(one, 1)).to eq(Numo::SFloat[2, 3, 4])
      end

      it 'accepts a block' do
        expect(MB::M.ltrim(Numo::Int32[1, 3, 5, 2, 4, 6], 1, &:odd?)).to eq([2, 4, 6])
        expect(MB::M.ltrim(Numo::SFloat[Float::NAN, Float::INFINITY, -Float::INFINITY, 2, 4, 6]) { |v| !v.finite? }).to eq(Numo::SFloat[2, 4, 6])
      end

      it 'returns an empty array if all values match' do
        expect(MB::M.ltrim(Numo::SFloat.zeros(6))).to eq(Numo::SFloat[])
        expect(MB::M.ltrim(Numo::SFloat.ones(6), 1)).to eq(Numo::SFloat[])
      end

      it 'returns the same type' do
        expect(MB::M.ltrim(Numo::SFloat[0,1,2])).to be_a(Numo::SFloat)
        expect(MB::M.ltrim(Numo::Int32[0,1,2])).to be_a(Numo::Int32)
      end
    end

    context 'with Array' do
      let(:zero) { [0, 0, 0, 1, 2, 3] }
      let(:one) { [1, 1, 1, 2, 3, 4] }

      it 'returns an empty array for an empty array' do
        expect(MB::M.ltrim([])).to eq([])
      end

      it 'accepts a value parameter' do
        expect(MB::M.ltrim(zero, 1)).to eq(zero)
        expect(MB::M.ltrim(zero, 0)).to eq([1, 2, 3])

        expect(MB::M.ltrim(one, 0)).to eq(one)
        expect(MB::M.ltrim(one, 1)).to eq([2, 3, 4])
      end

      it 'accepts a block' do
        expect(MB::M.ltrim([1, 3, 5, 2, 4, 6], 1, &:odd?)).to eq([2, 4, 6])
        expect(MB::M.ltrim([Float::NAN, Float::INFINITY, -Float::INFINITY, 2, 4, 6]) { |v| !v.finite? }).to eq([2, 4, 6])
      end

      it 'returns an empty array if all values match' do
        expect(MB::M.ltrim([0] * 6)).to eq([])
        expect(MB::M.ltrim([1] * 6, 1)).to eq([])
      end
    end

    it 'raises an error for a non-array type' do
      expect { MB::M.ltrim('hello', 'h') }.to raise_error(ArgumentError, /array/i)
    end
  end

  describe '.rol' do
    context 'with Numo::NArray' do
      it 'returns the same array with a rotation of 0' do
        expect(MB::M.rol(Numo::SFloat[1,2,3], 0)).to eq(Numo::SFloat[1,2,3])
      end

      it 'can rotate left' do
        expect(MB::M.rol(Numo::SFloat[1,2,3], 1)).to eq(Numo::SFloat[2,3,1])
        expect(MB::M.rol(Numo::SFloat[1,2,3], 2)).to eq(Numo::SFloat[3,1,2])
      end

      it 'can rotate right' do
        expect(MB::M.rol(Numo::SFloat[1,2,3], -1)).to eq(Numo::SFloat[3,1,2])
        expect(MB::M.rol(Numo::SFloat[1,2,3], -2)).to eq(Numo::SFloat[2,3,1])
      end

      it 'wraps rotation amounts to fit within the array length' do
        expect(MB::M.rol(Numo::SFloat[1,2,3], 10)).to eq(Numo::SFloat[2,3,1])
      end

      it 'does nothing if the rotation amount is a multiple of the array length' do
        expect(MB::M.rol(Numo::SFloat[1,2,3], 3)).to eq(Numo::SFloat[1,2,3])
        expect(MB::M.rol(Numo::SFloat[1,2,3], 6)).to eq(Numo::SFloat[1,2,3])
        expect(MB::M.rol(Numo::SFloat[1,2,3], -3)).to eq(Numo::SFloat[1,2,3])
      end

      it 'does nothing if the array is empty' do
        expect(MB::M.rol(Numo::SFloat[], 5)).to eq(Numo::SFloat[])
      end

      it 'does nothing if the array length is 1' do
        expect(MB::M.rol(Numo::SFloat[5], 1)).to eq(Numo::SFloat[5])
      end
    end

    context 'with a Ruby Array' do
      it 'returns the same array with a rotation of 0' do
        expect(MB::M.rol([1,2,3], 0)).to eq([1,2,3])
      end

      it 'can rotate left' do
        expect(MB::M.rol([1,2,3], 1)).to eq([2,3,1])
        expect(MB::M.rol([1,2,3], 2)).to eq([3,1,2])
      end

      it 'can rotate right' do
        expect(MB::M.rol([1,2,3], -1)).to eq([3,1,2])
        expect(MB::M.rol([1,2,3], -2)).to eq([2,3,1])
      end

      it 'wraps rotation amounts to fit within the array length' do
        expect(MB::M.rol([1,2,3], 10)).to eq([2,3,1])
      end

      it 'does nothing if the rotation amount is a multiple of the array length' do
        expect(MB::M.rol([1,2,3], 0)).to eq([1,2,3])
      end

      it 'does nothing if the array is empty' do
        expect(MB::M.rol([], 5)).to eq([])
      end

      it 'does nothing if the array length is 1' do
        expect(MB::M.rol([5], 1)).to eq([5])
      end
    end
  end

  describe '.ror' do
    # TODO: currently ror calls rol so rol tests cover ror.  But if ror and rol
    # were ever split for some reason, we could just negate the parameters from
    # the rol tests to generate ror tests.

    it 'returns the same array with a rotation of 0' do
      expect(MB::M.ror(Numo::SFloat[1,2,3], 0)).to eq(Numo::SFloat[1,2,3])
    end

    it 'can rotate left' do
      expect(MB::M.ror(Numo::SFloat[1,2,3], -1)).to eq(Numo::SFloat[2,3,1])
      expect(MB::M.ror(Numo::SFloat[1,2,3], -2)).to eq(Numo::SFloat[3,1,2])
    end

    it 'can rotate right' do
      expect(MB::M.ror(Numo::SFloat[1,2,3], 1)).to eq(Numo::SFloat[3,1,2])
      expect(MB::M.ror(Numo::SFloat[1,2,3], 2)).to eq(Numo::SFloat[2,3,1])
    end

    it 'can rotate a Ruby Array' do
      expect(MB::M.ror([1,2,3], 1)).to eq([3,1,2])
      expect(MB::M.ror([1,2,3], 2)).to eq([2,3,1])
    end

    it 'wraps around rotation amounts' do
      expect(MB::M.ror([1,2,3], 5)).to eq([2,3,1])
    end
  end

  describe '.shl' do
    it 'returns the same array with a shift of 0' do
      expect(MB::M.shl(Numo::SFloat[1,2,3], 0)).to eq(Numo::SFloat[1,2,3])
    end

    it 'can shift left' do
      expect(MB::M.shl(Numo::SFloat[1,2,3], 1)).to eq(Numo::SFloat[2,3,0])
      expect(MB::M.shl(Numo::SFloat[1,2,3], 2)).to eq(Numo::SFloat[3,0,0])
      expect(MB::M.shl(Numo::SFloat[1,2,3], 3)).to eq(Numo::SFloat[0,0,0])
    end

    it 'cannot shift right' do
      expect { MB::M.shl(Numo::SFloat[1,2,3], -1) }.to raise_error(ArgumentError)
    end
  end

  describe '.shr' do
    it 'returns the same array with a shift of 0' do
      expect(MB::M.shr(Numo::SFloat[1,2,3], 0)).to eq(Numo::SFloat[1,2,3])
    end

    it 'can shift right' do
      expect(MB::M.shr(Numo::SFloat[1,2,3], 1)).to eq(Numo::SFloat[0,1,2])
      expect(MB::M.shr(Numo::SFloat[1,2,3], 2)).to eq(Numo::SFloat[0,0,1])
      expect(MB::M.shr(Numo::SFloat[1,2,3], 3)).to eq(Numo::SFloat[0,0,0])
    end

    it 'cannot shift left' do
      expect { MB::M.shr(Numo::SFloat[1,2,3], -1) }.to raise_error(ArgumentError)
    end
  end

  describe '.fetch_bounce' do
    let(:a) { [1, 2, 3, 4, 5] }
    let(:na) { Numo::SFloat.cast(a) }

    it 'returns elements for valid indicies normally' do
      expect(MB::M.fetch_bounce(a, 0)).to eq(1)
      expect(MB::M.fetch_bounce(a, 1)).to eq(2)
      expect(MB::M.fetch_bounce(a, 2)).to eq(3)
      expect(MB::M.fetch_bounce(a, 3)).to eq(4)
      expect(MB::M.fetch_bounce(a, 4)).to eq(5)
    end

    it 'returns expected elements below 0' do
      expect(MB::M.fetch_bounce(a, -1)).to eq(2)
      expect(MB::M.fetch_bounce(a, -2)).to eq(3)
      expect(MB::M.fetch_bounce(a, -3)).to eq(4)
      expect(MB::M.fetch_bounce(a, -4)).to eq(5)
      expect(MB::M.fetch_bounce(a, -5)).to eq(4)
    end

    it 'returns expected elements beyond the end' do
      expect(MB::M.fetch_bounce(a, 5)).to eq(4)
      expect(MB::M.fetch_bounce(a, 6)).to eq(3)
      expect(MB::M.fetch_bounce(a, 7)).to eq(2)
      expect(MB::M.fetch_bounce(a, 8)).to eq(1)
      expect(MB::M.fetch_bounce(a, 9)).to eq(2)
    end

    it 'can retrieve elements from a Numo::NArray' do
      expect(MB::M.fetch_bounce(na, -5)).to eq(4)
      expect(MB::M.fetch_bounce(na, 2)).to eq(3)
      expect(MB::M.fetch_bounce(na, 9)).to eq(2)
    end
  end

  describe '.fractional_index' do
    let(:array) { [ 1, 3, 5, -5, 1.5, 2.5 + 1.0i, 1.0 - 1.0i ] }
    let(:narray) { Numo::SComplex[1, 3, 5i] }

    it 'can return original values' do
      expect(MB::M.fractional_index(array, 0)).to eq(1)
      expect(MB::M.fractional_index(array, 1)).to eq(3)
      expect(MB::M.fractional_index(array, -1)).to eq(1.0 - 1.0i)
    end

    it 'can interpolate integers' do
      expect(MB::M.fractional_index(array, 0.25)).to eq(1.5)
    end

    it 'can interpolate around the end of the array' do
      expect(MB::M.fractional_index(array, -0.5)).to eq(1 - 0.5i)
      expect(MB::M.fractional_index(array, -0.75)).to eq(1 - 0.75i)
    end

    it 'can interpolate with negative indices' do
      expect(MB::M.fractional_index(array, -4.5)).to eq(0)
      expect(MB::M.fractional_index(array, -4.75)).to eq(2.5)
    end

    it 'can interpolate integers and floats' do
      expect(MB::M.fractional_index(array, 3.25)).to eq(-3.375)
    end

    it 'can interpolate complex values' do
      expect(MB::M.fractional_index(array, 5.5)).to eq(1.75)
    end

    it 'can interpolate a Numo::NArray' do
      expect(MB::M.fractional_index(narray, 0)).to eq(1)
      expect(MB::M.fractional_index(narray, -0.5)).to eq(0.5 + 2.5i)
      expect(MB::M.fractional_index(narray, 1.5)).to eq(1.5 + 2.5i)
    end

    it 'can interpolate across Arrays' do
      a1 = [1, 2, 3]
      a2 = [4, 5, 6]
      a = [a1, a2]
      expect(MB::M.fractional_index(a, 0.5)).to eq([2.5, 3.5, 4.5])
    end

    it 'can interpolate across Hashes' do
      h1 = {a: 1, b: 2}
      h2 = {a: 3, b: 4}
      a = [h1, h2]
      expect(MB::M.fractional_index(a, 0.25)).to eq({a: 1.5, b: 2.5})
    end

    pending 'can accept an interpolator function like smoothstep'
  end

  describe '#convolve' do
    let(:array_int) { [1, 2, 3] }
    let(:array_float) { [0.5, -1, 0.25] }
    let(:array_float4) { [0.5, -1, 0.25, 9] }
    let(:array_complex) { [1, 2.0, 3+3i] }
    let(:i16) { Numo::Int16[1, 3, 5] }
    let(:i32) { Numo::Int32[1, 2, 4, -1] }
    let(:i64) { Numo::Int64[-1, 1, -1, -2] }
    let(:sfloat) { Numo::SFloat[-0.1, 0.5, -0.3] }
    let(:dfloat) { Numo::DFloat[-0.25, 0.75, -0.1] }
    let(:scomplex) { Numo::SComplex[-0.1 - 0.25i, 0.25 - 0.75i, 0.3] }
    let(:dcomplex) { Numo::DComplex[5, -3i, 1i, -1] }

    it "can produce Pascal's triangle" do
      result = Array.new(5) do |i|
        ([[1, 1]] * (i + 1)).reduce(&MB::M.method(:convolve))
      end

      expect(result).to eq([
        [1, 1],
        [1, 2, 1],
        [1, 3, 3, 1],
        [1, 4, 6, 4, 1],
        [1, 5, 10, 10, 5, 1],
      ])
    end

    shared_examples_for :type_correct_convolution do
      it "returns the expected class" do
        result = MB::M.convolve(a1, a2)
        expect(result).to be_a(expected.class)

        result = MB::M.convolve(a2, a1)
        expect(result).to be_a(expected.class)
      end

      it "convolves correctly" do
        result = MB::M.convolve(a1, a2)
        expect(MB::M.round(result, 6)).to eq(expected)

        result = MB::M.convolve(a2, a1)
        expect(MB::M.round(result, 6)).to eq(expected)
      end
    end

    # Expected values below were calculated using Octave's conv() function

    context 'with Ruby Arrays' do
      it 'can convolve Arrays of the same length' do
        expected = [0.5, 0, -0.25, -2.5, 0.75]
        expect(MB::M.convolve(array_int, array_float)).to eq(expected)
        expect(MB::M.convolve(array_float, array_int)).to eq(expected)
      end

      it 'can convolve Arrays of differing lengths' do
        expected = [0.25, -1.0, 1.25, 4.0, -8.9375, 2.25]
        expect(MB::M.convolve(array_float4, array_float)).to eq(expected)
        expect(MB::M.convolve(array_float, array_float4)).to eq(expected)
      end

      it 'can convolve Arrays containing Complex values' do
        expected = [1, 4, 10+3i, 12+6i, 9+9i]

        expect(MB::M.convolve(array_int, array_complex)).to eq(expected)
        expect(MB::M.convolve(array_complex, array_int)).to eq(expected)
      end
    end

    context 'with Numo::NArrays' do
      context 'with Numo::SFloat and Numo::DComplex returning Numo::DComplex' do
        let(:a1) { sfloat }
        let(:a2) { dcomplex }
        let(:expected) { Numo::DComplex[-0.5+0i, 2.5+0.3i, -1.5-1.6i, 0.1+1.4i, -0.5-0.3i, 0.3+0i] }

        it_behaves_like :type_correct_convolution
      end

      context 'with Numo::DFloat and Numo::SComplex returning Numo::DComplex' do
        let(:a1) { dfloat }
        let(:a2) { scomplex }
        let(:expected) { Numo::DComplex[0.025+0.0625i, -0.1375+0i, 0.1225-0.5375i, 0.2+0.075i, -0.03+0i] }

        it_behaves_like :type_correct_convolution
      end

      context 'with Numo::Int16 and Numo::SComplex returning Numo::SComplex' do
        let(:a1) { i16 }
        let(:a2) { scomplex }
        let(:expected) { Numo::SComplex[-0.1-0.25i, -0.05-1.5i, 0.55-3.5i, 2.15-3.75i, 1.5+0i] }

        it_behaves_like :type_correct_convolution
      end

      context 'with Numo::Int32 and Numo::SFloat returning Numo::DFloat' do
        let(:a1) { i32 }
        let(:a2) { sfloat }
        let(:expected) { Numo::DFloat[-0.1, 0.3, 0.3, 1.5, -1.7, 0.3] }

        it_behaves_like :type_correct_convolution
      end

      context 'with Numo::Int64 and Numo::SComplex returning Numo::DComplex' do
        let(:a1) { i64 }
        let(:a2) { scomplex }
        let(:expected) { Numo::DComplex[0.1+0.25i, -0.35+0.5i, 0.05-0.5i, 0.25+1.25i, -0.8+1.5i, -0.6+0i] }

        it_behaves_like :type_correct_convolution
      end
    end

    context 'with Array and NArray (in either order)' do
      context 'with float Array and Numo::SFloat returning Numo::DFloat' do
        let(:a1) { array_float }
        let(:a2) { sfloat }
        let(:expected) { Numo::DFloat[-0.05, 0.35, -0.675, 0.425, -0.075] }

        it_behaves_like :type_correct_convolution
      end

      context 'with complex Array amd Numo::DFloat returning Numo::DComplex' do
        let(:a1) { array_complex }
        let(:a2) { dfloat }
        let(:expected) { Numo::DComplex[-0.25+0i, 0.25+0i, 0.65-0.75i, 2.05+2.25i, -0.3-0.3i] }

        it_behaves_like :type_correct_convolution
      end

      context 'with float Array and Numo::SComplex returning Numo::DComplex' do
        let(:a1) { array_float }
        let(:a2) { scomplex }
        let(:expected) { Numo::DComplex[-0.05-0.125i, 0.225-0.125i, -0.125+0.6875i, -0.2375-0.1875i, 0.075+0i] }

        it_behaves_like :type_correct_convolution
      end
    end
  end

  describe '#find_first' do
    it 'can operate on a Ruby Array' do
      expect(MB::M.find_first([0, 1, 2, 3, 4, 3, 2, 1], 3)).to eq(3)
    end

    it 'can operate on a Numo::SFloat' do
      expect(MB::M.find_first(Numo::SFloat[0, 1, 2, 3, 4, 3, 2, 1], 3)).to eq(3)
    end

    it 'returns nil if there is no match' do
      expect(MB::M.find_first([0, 0, 0], 3)).to eq(nil)
      expect(MB::M.find_first(Numo::SFloat[1, 1, 1], 0)).to eq(nil)
    end

    it 'returns nil for empty arrays' do
      expect(MB::M.find_first([], 0)).to eq(nil)
      expect(MB::M.find_first(Numo::SFloat[], 0)).to eq(nil)
    end

    it 'accepts a block' do
      prior = nil
      expect(
        MB::M.find_first(Numo::SFloat[-1, -2, -1, 0, 1]) { |v, idx|
          if idx > 0
            next true if prior && prior < 0 && v >= 0
          end
          prior = v
          false
        }
      ).to eq(3)
    end

    it 'returns nil if the block always returns false' do
      expect(
        MB::M.find_first(Numo::SFloat[-1, -2, -1, 0, 1]) { false }
      ).to eq(nil)
    end
  end

  describe '#find_first_not' do
    it 'can operate on a Ruby Array' do
      expect(MB::M.find_first_not([3, 3, 3, 0, 1, 2, 3, 4, 3, 2, 1], 3)).to eq(3)
    end

    it 'can operate on a Numo::SFloat' do
      expect(MB::M.find_first_not(Numo::SFloat[3, 3, 0, 1, 2, 3, 4, 3, 2, 1], 3)).to eq(2)
    end

    it 'returns nil if there is no match' do
      expect(MB::M.find_first_not([0, 0, 0], 0)).to eq(nil)
      expect(MB::M.find_first_not(Numo::SFloat[1, 1, 1], 1)).to eq(nil)
    end

    it 'returns nil for empty arrays' do
      expect(MB::M.find_first_not([], 0)).to eq(nil)
      expect(MB::M.find_first_not(Numo::SFloat[], 0)).to eq(nil)
    end

    it 'accepts a block' do
      expect(
        MB::M.find_first_not(Numo::SFloat[-1, -2, -1, 0, 1]) { |v, _idx| v <= 0 }
      ).to eq(4)
    end

    it 'returns nil if the block always returns true' do
      expect(
        MB::M.find_first_not(Numo::SFloat[-1, -2, -1, 0, 1]) { true }
      ).to eq(nil)
    end
  end

  describe '#skip_leading' do
    # Note: this is an alias for ltrim
    it 'skips zeros on a Ruby Array' do
      expect(MB::M.skip_leading([0, 0, 0, 1, 2], 0)).to eq([1, 2])
    end

    it 'skips 1i on a NArray' do
      expect(MB::M.skip_leading(Numo::DComplex[1i, 1i, 1i, 0, 1, 2], 1i)).to eq([0, 1, 2])
    end

    it 'returns an empty array if all values match' do
      expect(MB::M.skip_leading([5], 5)).to eq([])
      expect(MB::M.skip_leading(Numo::DFloat[5], 5)).to eq(Numo::DFloat[])
    end

    it 'returns an empty array for an empty array' do
      expect(MB::M.skip_leading([], 0)).to eq([])
      expect(MB::M.skip_leading(Numo::DFloat[], 0)).to eq(Numo::DFloat[])
    end

    it 'raises an error for an unsupported empty type' do
      expect { MB::M.skip_leading({}, 0) }.to raise_error(ArgumentError, /Hash/)
    end
  end

  describe '#find_sign_change' do
    it 'finds the correct index' do
      expect(MB::M.find_sign_change(Numo::SFloat[0, 1, 2, 1, 0, -1, 0, 1])).to eq(6)
    end

    it 'returns nil for an empty array' do
      expect(MB::M.find_sign_change(Numo::SFloat[])).to eq(nil)
    end

    it 'can find a sign change in a Ruby Array' do
      expect(MB::M.find_sign_change([0,3,2,1,0,-1,-2,-1], false)).to eq(4)
    end

    it 'returns nil if there is never a rising zero crossing' do
      expect(MB::M.find_sign_change([0,3,2,1,0,-1,-2,-1])).to eq(nil)
    end

    it 'is aliased to find_zero_crossing' do
      expect(MB::M.find_zero_crossing(Numo::SFloat[0, 1, 2, 1, 0, -1, 0, 1])).to eq(6)
    end

    it 'can find falling edges' do
      expect(MB::M.find_sign_change(Numo::SFloat[0, 1, 2, 1, 0, -1, 0, 1], false)).to eq(4)
    end
  end

  describe '#select_sign_changes' do
    let(:data) {
      Numo::SFloat[0].concatenate(
        ([Numo::SFloat[0, 1, 0, -1]] * 30).reduce(&:concatenate)
      ).concatenate(
        Numo::SFloat[1, 2, 3, 4, 5]
      )
    }

    it 'can return a single cycle' do
      expect(MB::M.select_sign_changes(data, 1)).to eq(Numo::SFloat[0, 1, 0, -1])
    end

    it 'can select cycles from a Ruby Array' do
      expect(MB::M.select_sign_changes(data.to_a, 2)).to eq([0, 1, 0, -1] * 2)
    end

    it 'can return multiple cycles' do
      expect(MB::M.select_sign_changes(data, 3)).to eq(Numo::SFloat[0, 1, 0, -1, 0, 1, 0, -1, 0, 1, 0, -1])
    end

    it 'can return the expected maximum number of sign changes' do
      expect(MB::M.select_sign_changes(data.to_a, 29)).to eq([0, 1, 0, -1] * 29)
    end

    it 'returns all of the full cycles if count is nil or false' do
      expect(MB::M.select_sign_changes(data.to_a, nil)).to eq([0, 1, 0, -1] * 29)
      expect(MB::M.select_sign_changes(data.to_a, false)).to eq([0, 1, 0, -1] * 29)
    end

    it 'returns nil if there are not enough sign changes' do
      expect(MB::M.select_sign_changes(data, 30)).to eq(nil)
    end

    it 'returns nil for an empty array' do
      expect(MB::M.select_sign_changes([], 1)).to eq(nil)
    end

    it 'returns nil if there are no matching rising sign changes' do
      expect(MB::M.select_sign_changes(Numo::DFloat[1, 2, 3, -1], 1)).to eq(nil)
    end

    it 'can find falling changes as well' do
      expect(MB::M.select_sign_changes(data, 2, false)).to eq(Numo::SFloat[0, -1, 0, 1, 0, -1, 0, 1])
    end

    it 'can find falling changes in a Ruby Array' do
      expect(MB::M.select_sign_changes(data.to_a, 1, false)).to eq([0, -1, 0, 1])
    end

    it 'returns nil if there are no matching falling sign changes' do
      expect(MB::M.select_sign_changes(Numo::DFloat[-1, 2, 3], 1, false)).to eq(nil)
    end

    it 'raises an error if count is 0' do
      expect { MB::M.select_sign_changes(data, 0) }.to raise_error(/>= 1/)
    end
  end
end
