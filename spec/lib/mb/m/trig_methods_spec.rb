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
  end

  context 'second cosecant antiderivative' do
    tests = {
      -Math::PI => -2.46740110027234i,
      -Math::PI + 0.01 => 0.0629831458876042 - 2.45169313700439i,
      -Math::PI + 0.05 => 0.234440500179617 - 2.38886128393260i,
      -Math::PI + 0.1 => 0.399545439850513 - 2.31032146759285i,
      -Math::PI * 3 / 4 => 1.50576150501180 - 1.23370055013617i,
      -Math::PI / 2 => 1.83193118835444,
      -Math::PI / 4 => 1.50576150501180 + 1.23370055013617i,
      -0.1 => 0.399545439850514 + 2.31032146759285i,
      -0.097 => 0.390515213280227 + 2.31503385657324i,
      -0.093 => 0.378329825857585 + 2.32131704188041i,
      -0.01 => 0.0629831458876052 + 2.45169313700439i,
      0 => 2.46740110027234i,
      0.01 => -0.0629831458876052 + 2.45169313700439i,
      0.093 => -0.378329825857585 + 2.32131704188041i,
      0.097 => -0.390515213280227 + 2.31503385657324i,
      0.1 => -0.399545439850514 + 2.31032146759285i,
      0.5 => -1.18964418922697 + 1.68200293687489i,
      Math::PI / 4 => -1.50576150501180 + 1.23370055013617i,
      1 => -1.66434523928990 + 0.896604773477443i,
      Math::PI / 2 => -1.83193118835444,
      Math::PI - 0.1 => -0.399545439850513 - 2.31032146759285i,
      Math::PI - 0.095 => -0.384443605455944 - 2.31817544922682i,
      Math::PI - 0.05 => -0.234440500179617 - 2.38886128393260i,
      Math::PI - 0.01 => -0.0629831458876042 - 2.45169313700439i,
      Math::PI => -2.46740110027234i,
    }

    describe '#csc_int_int_direct' do
      tests.each do |input, output|
        it "returns expected value for #{input}" do
          expect(MB::M.round(MB::M.csc_int_int_direct(input), 5)).to eq(MB::M.round(output, 5))
        end
      end
    end

    describe '#csc_int_int' do
      tests.each do |input, output|
        it "returns expected value for #{input}" do
          expect(MB::M.round(MB::M.csc_int_int(input), 5)).to eq(MB::M.round(output, 5))
        end
      end
    end

    describe '#cot_int' do
      tests = {
        # Values calculated in Sage
        -Math::PI => -0.220635600152652 - 0.5i,
        -Math::PI * 3 / 2 => -0.441271200305303,
        -Math::PI / 2 - 0.01 => 2.93174504810231 - 0.996816901138161i,
        -Math::PI / 2 + 0.01 => 2.93174504810230 + 0.996816901138161i,
        0 => -0.220635600152652 + 0.5i,
        1 => -0.414984380475852 + 0.181690113816209i,
        Math::PI / 4 => -0.390867726245916 + 0.250000000000000i,
        Math::PI / 2 => -0.441271200305303,
        Math::PI * 3 / 2 - 0.01 => 2.93174504810231 - 0.996816901138161i,
        Math::PI * 3 / 2 + 0.01 => 2.93174504810233 + 0.996816901138161i,
        Math::PI => -0.220635600152652 - 0.5i,
      }

      tests.each do |input, output|
        it "returns expected value for #{input}" do
          result = MB::M.round(MB::M.cot_int(input), 6)
          expect(result).to eq(MB::M.round(output, 6))
        end
      end
    end

    describe '#cycloid' do
      tests = {
        -Math::PI * 2 => 0,
        -Math::PI * 3 / 2 - 1 => 1,
        -Math::PI => 2,
        -Math::PI / 2 + 1 => 1,
        -0.1585290151921035 => 0.45969769413186023,
        0 => 0,
        0.0001665833531718508 => 0.0049958347219741794,
        Math::PI / 2 - 1 => 1,
        Math::PI => 2,
        Math::PI * 3 / 2 + 1 => 1,
        Math::PI * 2 => 0,
      }

      tests.each do |input, output|
        it "returns expected value for #{input}" do
          expect(MB::M.cycloid(input)).to be_within(0.00001).of(output)
        end
      end

      it 'closely matches parametric cycloid' do
        t = Numo::DFloat.linspace(-2.01 * Math::PI, 2.01 * Math::PI, 8041)
        x = t.map { |v| v - Math.sin(v) }
        y = t.map { |v| 1 - Math.cos(v) }

        result = x.map { |v| MB::M.cycloid(v) }
        diff = result - y
        expect(diff.abs.max).to be < 0.00001
      end
    end

    describe '#cycloid_parametric' do
      it 'uses the power parameter' do
        baseline = MB::M.cycloid_parametric(1)
        result = MB::M.cycloid_parametric(1, power: 2)
        expect(result[0]).to eq(baseline[0])
        expect(result[1]).to be_within(0.000000001).of(baseline[1] ** 2 / 2)

        baseline = MB::M.cycloid_parametric(3)
        result = MB::M.cycloid_parametric(3, power: 2)
        expect(result[0]).to eq(baseline[0])
        expect(result[1]).to be_within(0.000000001).of(baseline[1] ** 2 / 2)

        baseline = MB::M.cycloid_parametric(3)
        result = MB::M.cycloid_parametric(3, power: 0.6)
        expect(result[0]).to eq(baseline[0])
        expect(result[1]).to be_within(0.000000001).of(baseline[1] ** 0.6 * 2 / 2 ** 0.6)
      end
    end
  end
end
