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
    pending
  end
end
