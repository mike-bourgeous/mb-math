RSpec.describe(MB::M::ExponentialMethods) do
  describe '#safe_power' do
    it 'scales positive values' do
      expect(MB::M.safe_power(0.25, 0.5)).to eq(0.5)
    end

    it 'scales negative values' do
      expect(MB::M.safe_power(-0.25, 0.5)).to eq(-0.5)
    end
  end

  describe '#polylog' do
    tests = {
      # https://en.wikipedia.org/wiki/Spence%27s_function#Special_values
      [2, -1]  => -Math::PI ** 2 / 12,
      [2, 0]   => 0,
      [2, 0.5] => Math::PI ** 2 / 12 - Math.log(2) ** 2 / 2,
      [2, 1] => Math::PI ** 2 / 6,
      [2, 2] => Math::PI ** 2 / 4 - Math::PI * 1i * Math.log(2),

      # https://en.wikipedia.org/wiki/Polylogarithm#Particular_values
      [1, 0.5] => Math.log(2),
      [3, 0.5] => Math.log(2) ** 3 / 6 - Math::PI ** 2 * Math.log(2) / 12 + 1.20205690315959 * 7.0 / 8,

      # Calculated in Sage
      [0, 2] => -2,
      [0, 1i] => -0.5+0.5i,
      [0, 1+2i] => -1 + 0.5i,
      [1, 1+2i] => -CMath.log(-2i),
      [1, 2] => -1i * Math::PI,
      [2, 1i] => -0.205616758356028 + 0.915965594177219i,
      [3, -1.5-2.5i] => -1.57834074765320 - 1.82109227957298i,
    }

    tests.each do |k, v|
      it "returns expected value for #{k}" do
        expect(MB::M.round(MB::M.polylog(*k), 6)).to eq(MB::M.round(v, 6))
      end
    end
  end
end
