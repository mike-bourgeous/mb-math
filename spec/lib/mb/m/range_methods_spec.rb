RSpec.describe(MB::M::RangeMethods) do
  describe '.scale' do
    it 'acceps reverse ranges' do
      expect(MB::M.scale(0.5, -1.0..1.0, 1.0..-1.0)).to eq(-0.5)
      expect(MB::M.scale(0.5, 1.0..-1.0, -1.0..1.0)).to eq(-0.5)
      expect(MB::M.scale(0.5, 1.0..-1.0, 2.0..1.0)).to eq(1.75)
    end

    it 'can scale an NArray' do
      expect(MB::M.scale(Numo::SFloat[1, 2, 3], 0.0..1.0, 0.0..2.0)).to eq(Numo::SFloat[2, 4, 6])
    end

    it 'can scale complex numbers' do
      expect(MB::M.scale(1+1i, 0.0..1.0, 0.0..2.0)).to eq(2+2i)
    end

    it 'can scale Numo::DComplex' do
      expect(MB::M.scale(Numo::DComplex[1+1i], 0.0..1.0, 0.0..-2.0)).to eq(Numo::DComplex[-2-2i])
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

  describe '.min' do
    it 'returns the lesser number' do
      expect(MB::M.min(-1, 1)).to eq(-1)
    end
  end

  describe '.max' do
    it 'returns the greater number' do
      expect(MB::M.max(-1, 1)).to eq(1)
    end
  end

  describe '.max_abs' do
    it 'returns the number with the larger magnitude' do
      expect(MB::M.max_abs(-32, 16)).to eq(-32)
    end

    it 'can process Complex numbers' do
      expect(MB::M.max_abs(0+16i, 8)).to eq(0+16i)
    end
  end
end
