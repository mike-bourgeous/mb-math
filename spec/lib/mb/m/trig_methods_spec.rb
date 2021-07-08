RSpec.describe(MB::M::TrigMethods) do
  describe '#csc_int' do
    it 'returns expected values for real arguments' do
      expect(MB::M.round(MB::M.csc_int(2), 6)).to eq(0.443022724.round(6))
      expect(MB::M.round(MB::M.csc_int(4), 6)).to eq(MB::M.round(0.781634072 - 1i * Math::PI, 6))
      expect(MB::M.round(MB::M.csc_int(Math::PI / 2), 6)).to eq(0)
      expect(MB::M.round(MB::M.csc_int(3.0 * Math::PI / 2), 6)).to eq(MB::M.round(0 - 1i * Math::PI, 6))
      expect(MB::M.round(MB::M.csc_int(2 + 2.0 * Math::PI), 6)).to eq(0.443022724.round(6))
      expect(MB::M.round(MB::M.csc_int(4 + 2.0 * Math::PI), 6)).to eq(MB::M.round(0.781634072 - 1i * Math::PI, 6))
      expect(MB::M.round(MB::M.csc_int(-12), 6)).to eq(-1.23441073580.round(6))
      expect(MB::M.round(MB::M.csc_int(-7), 6)).to eq(MB::M.round(-0.9819348235 - 1i * Math::PI, 6))
    end

    pending 'returns expected values for complex arguments'
  end

  describe '#csc_int_int' do
    tests = {
      -Math::PI => -2.46740110027234i,
      -Math::PI * 3 / 4 => 1.50576150501180 - 1.23370055013617i,
      -Math::PI / 2 => 1.83193118835444,
      -Math::PI / 4 => 1.50576150501180 + 1.23370055013617i,
      -0.1 => 0.399545439850514 + 2.31032146759285i,
      0 => 2.46740110027234i,
      0.01 => -0.0629831458876051 + 2.45169313700439i,
      0.1 => -0.399545439850514 + 2.31032146759285i,
      0.5 => -1.18964418922697 + 1.68200293687489i,
      Math::PI / 4 => -1.50576150501180 + 1.23370055013617i,
      1 => -1.66434523928990 + 0.896604773477443i,
      Math::PI / 2 => -1.83193118835444,
      Math::PI => -2.46740110027234i,
    }

    tests.each do |input, output|
      it "returns expected value for #{input}" do
        expect(MB::M.round(MB::M.csc_int_int(input), 6)).to eq(MB::M.round(output, 6))
      end
    end

    pending 'complex arguments'
  end
end
