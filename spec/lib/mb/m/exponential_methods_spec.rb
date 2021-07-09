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

  describe '#polylog_zeta' do
    tests = {
      # Calculated using Sage
      -5 => -1.0 / 252,
      -4 => 0,
      -3 => 1.0 / 120,
      -2 => 0,
      -1 => -1.0 / 12,
      -0.5 => -0.207886224977355,
      0 => -0.5,
      0.1 => -0.603037519856242,
      0.5 => -1.46035450880959,
      0.9 => -9.43011401940226,
      0.99 => -99.4235129777281,
      1.01 => 100.577943338497,
      1.1 => 10.5844484649508,
      2 => Math::PI ** 2 / 6,
      3 => 1.20205690315959,
      4 => Math::PI ** 4 / 90,
      6 => Math::PI ** 6 / 945,
      1000 => 1,
      -10 => 0,
      -3.25 + 1.5i => 0.0105210241142660 + 0.0251899184269018i,
      -1.95 + 10.5i => 3.90456001838426 - 0.127043671700629i,
      0.5 ** 0.5 * (1 + 1i) => 0.0577551139518709 - 1.15351855877981i,
      1 - 1i => 0.582158059752004 + 0.926848564330807i,
      1 + 1i => 0.582158059752004 - 0.926848564330807i,
      1 + 0.001i => 0.577215669746715 - 999.999927184154i,
      2.3 - 3.7i => 0.829862343193918 + 0.0283489977196380i,
    }

    tests.each do |k, v|
      it "returns expected value for #{k}" do
        expect(MB::M.round(MB::M.sigfigs(MB::M::ExponentialMethods.polylog_zeta(k), 6), 8)).to eq(MB::M.round(MB::M.sigfigs(v, 6), 8))
      end
    end
  end

  describe '#polylog_bernoulli_polynomial' do
    tests = {
      [4, 0] => -1.0 / 30,
      [6, 4] => 69553.0 / 42,
      [1, -3] => -7.0 / 2,
      [4, 3 - 2.5i] => 25.0i / 4 - 37493.0 / 240,
      [3, 3 - 2.5i] => -245.0i / 8 - 255.0 / 8,
      [2, 1 + 1i] => 1i - 5.0 / 6,
      [2, 1 - 1i] => -1i - 5.0 / 6,
      [2, -1 - 1i] => 3i + 7.0 / 6,
      [2, -1 + 1i] => -3i + 7.0 / 6,
      [3, 1 + 1i] => -0.5i - 1.5,
      [3, 1 - 1i] => 0.5i - 1.5,
      [3, -1 - 1i] => -11.0i / 2 + 3.0 / 2,
      [3, -1 + 1i] => 11.0i / 2 + 3.0 / 2,
    }

    tests.each do |k, v|
      it "returns expected value for #{k}" do
        expect(MB::M.round(MB::M::ExponentialMethods.polylog_bernoulli_polynomial(*k), 6)).to eq(MB::M.round(v, 6))
      end
    end
  end

  describe '#polylog_bernoulli_number' do
    tests = {
      0 => 1,
      1 => -0.5,
      5 => 0,
      6 => 1.0 / 42,
      12 => -691.0 / 2730,
    }

    tests.each do |k, v|
      it "returns expected value for #{k}" do
        expect(MB::M::ExponentialMethods.polylog_bernoulli_number(k).round(6)).to eq(v.round(6))
      end
    end
  end

  describe '#polylog_harmonic' do
    tests = {
      0 => 0,
      1 => 1,
      2 => 1.5,
      3 => 11.0 / 6.0,
      4 => 25.0 / 12.0,
      37 => 4.20158622382167,
    }

    tests.each do |k, v|
      it "returns expected value for #{k}" do
        expect(MB::M::ExponentialMethods.polylog_harmonic(k).round(8)).to eq(v.round(8))
      end
    end
  end
end
