RSpec.describe(MB::M::ExponentialMethods) do
  describe '#safe_power' do
    it 'scales positive values' do
      expect(MB::M.safe_power(0.25, 0.5)).to eq(0.5)
    end

    it 'scales negative values' do
      expect(MB::M.safe_power(-0.25, 0.5)).to eq(-0.5)
    end

    it 'scales narrays' do
      expect(MB::M.safe_power(Numo::SFloat[1, 4, 16], 0.5)).to eq(Numo::SFloat[1, 2, 4])
    end

    it 'scales arrays' do
      expect(MB::M.safe_power([-1, -4, -16], 0.5)).to eq([-1, -2, -4])
    end

    it 'scales iterators' do
      expect(MB::M.safe_power((0..2).lazy.map { |v| (-4) ** v }, 0.5).to_a).to eq([1, -2, 4])
    end
  end
end
