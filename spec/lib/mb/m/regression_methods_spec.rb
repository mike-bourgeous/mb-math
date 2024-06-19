RSpec.describe(MB::M::RegressionMethods) do
  it 'returns the correct slope and intercept for y=x' do
    expect(MB::M.linear_regression(Numo::SFloat[0, 1, 2, 3, 4, 5])).to eq([1, 0])
  end

  it 'returns the correct slope and intercept for y=-x' do
    expect(MB::M.linear_regression(Numo::SFloat[0, -1, -2, -3, -4, -5])).to eq([-1, 0])
  end

  it 'returns the correct slope and intercept for y=2.5x+3.25' do
    expect(MB::M.linear_regression(Numo::SFloat[3.25, 5.75, 8.25])).to eq([2.5, 3.25])
  end
end
