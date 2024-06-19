RSpec.describe(MB::M::RegressionMethods) do
  context 'with perfect data' do
    it 'returns the correct slope and intercept for y=x' do
      expect(MB::M.linear_regression(Numo::SFloat[0, 1, 2, 3, 4, 5])).to eq([1, 0])
    end

    it 'returns the correct slope and intercept for y=-x' do
      expect(MB::M.linear_regression(Numo::SFloat[0, -1, -2, -3, -4, -5])).to eq([-1, 0])
    end

    it 'returns the correct slope and intercept for y=2x' do
      expect(MB::M.linear_regression(Numo::SFloat[0, 2, 4, 6, 8])).to eq([2, 0])
    end

    it 'returns the correct slope and intercept for y=-3.5x' do
      expect(MB::M.linear_regression(Numo::SFloat[0, -3.5, -7])).to eq([-3.5, 0])
    end

    it 'returns the correct slope and intercept for y=2.5x+3.25' do
      expect(MB::M.linear_regression(Numo::SFloat[3.25, 5.75, 8.25])).to eq([2.5, 3.25])
    end

    it 'returns the correct slope and intercept for y=-0.5x+0.125' do
      expect(MB::M.linear_regression(Numo::SFloat[0.125, -0.375, -0.875])).to eq([-0.5, 0.125])
    end

    it 'returns the correct slope and intercept for y=0.25x-1.25' do
      expect(MB::M.linear_regression(Numo::SFloat[-1.25, -1.0, -0.75, -0.5])).to eq([0.25, -1.25])
    end
  end

  context 'with noisy data' do
    pending 'TODO'
  end
end
