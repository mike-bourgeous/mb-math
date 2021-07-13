RSpec.describe(MB::M::ArrayMethods) do
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
  end

  describe '.zpad' do
    it 'defaults to right-pad' do
      expect(MB::M.zpad(Numo::SFloat[1], 2)).to eq(Numo::SFloat[1, 0])
    end

    it 'can pad an empty narray' do
      expect(MB::M.zpad(Numo::SFloat[], 2)).to eq(Numo::SFloat[0, 0])
    end
  end

  describe '.opad' do
    it 'defaults to right-pad' do
      expect(MB::M.opad(Numo::SFloat[2], 2)).to eq(Numo::SFloat[2, 1])
    end

    it 'can pad an empty narray' do
      expect(MB::M.opad(Numo::SFloat[], 2)).to eq(Numo::SFloat[1, 1])
    end
  end

  describe '.rol' do
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
  end

  describe '.ror' do
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
end
