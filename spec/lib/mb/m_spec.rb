RSpec.describe(MB::M, :aggregate_failures) do
  describe '.parse_complex' do
    tests = {
      '+1' => 1.0,
      '-1' => -1.0,
      '3' => 3.0,
      '.123' => 0.123,
      '.5 < -.3' => Complex.polar(0.5, -0.3.degrees),
      '+.5 < +.1' => Complex.polar(0.5, 0.1.degrees),
      '.3-.5i' => 0.3-0.5i,
      '1 + 1i' => 1+1i,
      '1-1.0i' => 1-1i,
      '+1-1i' => 1-1i,
      '-1+1i' => -1+1i,
      '1<5' => Complex.polar(1, 5.degrees),
      '+1<+5' => Complex.polar(1, 5.degrees),
      '1.0<-3.2' => Complex.polar(1, -3.2.degrees),
      '0.323 < +190' => Complex.polar(0.323, 190.degrees),
      'invalid' => ArgumentError,
      true => TypeError,
    }

    tests.each do |k, v|
      if v.is_a?(Numeric)
        it "parses #{k.inspect} correctly" do
          expect(MB::M.round(MB::M.parse_complex(k), 10)).to eq(MB::M.round(v, 10))
        end
      else
        it "raises an error for #{k.inspect}" do
          expect { MB::M.parse_complex(k) }.to raise_error(v)
        end
      end
    end
  end
end
