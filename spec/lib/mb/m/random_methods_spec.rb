RSpec.describe(MB::M::RandomMethods) do
  describe '#random_value' do
    it 'can generate integers' do
      10.times do
        expect(MB::M.random_value(0..100)).to be_a(Integer).and be_between(0, 100)
        expect(MB::M.random_value(-72..-23)).to be_a(Integer).and be_between(-72, -23)
      end
    end

    it 'can generate rationals' do
      max_denom = 0

      10.times do
        r = MB::M.random_value(-7r..-6r)
        expect(r).to be_a(Rational).and be_between(-7, -6)
        max_denom = r.denominator if r.denominator > max_denom

        r = MB::M.random_value(-1r..3r)
        expect(r).to be_a(Rational).and be_between(-1, 3)
        max_denom = r.denominator if r.denominator > max_denom

        r = MB::M.random_value((4r/3)..(5r/3))
        expect(r).to be_a(Rational).and be_between(4r/3, 5r/3)
        max_denom = r.denominator if r.denominator > max_denom
      end

      expect(max_denom).to be > 1
    end

    it 'can generate floats' do
      10.times do
        expect(MB::M.random_value(-0.75..-0.25)).to be_a(Float).and be_between(-0.75, -0.25)
      end
    end

    it 'generates a float from 0 to 1 by default' do
      10.times do
        expect(MB::M.random_value).to be_a(Float).and be_between(0, 1)
      end
    end

    it 'can generate complex values in rectangular coordinates' do
      max_abs = 0
      equal_count = 0

      1000.times do
        c = MB::M.random_value(complex: true)
        expect(c).to be_a(Complex)
        expect(c.real).to be_a(Float).and be_between(0, 1)
        expect(c.imag).to be_a(Float).and be_between(0, 1)

        equal_count += 1 if c.real == c.imag

        max_abs = c.abs if c.abs > max_abs
      end

      # Ensure real and imaginary values differ
      expect(equal_count).to be < 10

      # Ensure we're generating values in the corners outside the unit circle
      expect(max_abs).to be_between(1.0, Math.sqrt(2))
    end

    it 'accepts :rect as well as true for generating complex values' do
      10.times do
        c = MB::M.random_value(complex: :rect)
        expect(c).to be_a(Complex)
        expect(c.real).to be_a(Float).and be_between(0, 1)
        expect(c.imag).to be_a(Float).and be_between(0, 1)
      end
    end

    it 'can generate complex values in polar coordinates' do
      min_abs = 100
      max_abs = 0
      min_arg = 100
      max_arg = -100
      equal_count = 0

      1000.times do
        c = MB::M.random_value(complex: :polar)
        expect(c).to be_a(Complex)
        expect(c.real).to be_a(Float).and be_between(-1, 1)
        expect(c.imag).to be_a(Float).and be_between(-1, 1)
        expect(c.abs).to be_between(0, 1)

        equal_count += 1 if c.real == c.imag

        min_arg = c.arg if c.arg < min_arg
        max_arg = c.arg if c.arg > max_arg

        min_abs = c.abs if c.abs < min_abs
        max_abs = c.abs if c.abs > max_abs
      end

      # Ensure real and imaginary values differ
      expect(equal_count).to be < 10

      # Ensure we're staying within the unit circle
      expect(min_abs).to be_between(0.0, 0.2)
      expect(max_abs).to be_between(0.8, 1.0)

      # Ensure we're using the full range of angles
      expect((max_arg - min_arg) / Math::PI).to be_between(1.8, 2)
    end

    it 'can specify range of rectangular complex values' do
      equal_count = 0

      10.times do
        c = MB::M.random_value(-1.5..0.25, complex: true)
        expect(c).to be_a(Complex)
        expect(c.real).to be_a(Float).and be_between(-1.5, 0.25)
        expect(c.imag).to be_a(Float).and be_between(-1.5, 0.25)

        equal_count += 1 if c.real == c.imag
      end

      # Ensure real and imaginary values differ
      expect(equal_count).to be < 10
    end

    it 'can specify radius range of polar complex values' do
      # First range fixes output to just a radius of 5 to make sure we can
      # generate random angles on a fixed circle
      [5.0..5.0, 2.0..10.0].each do |range|
        min_abs = 100
        max_abs = 0
        min_arg = 100
        max_arg = -100
        equal_count = 0

        1000.times do
          c = MB::M.random_value(range, complex: :polar)
          expect(c).to be_a(Complex)
          expect(c.real).to be_a(Float).and be_between(-range.end, range.end)
          expect(c.imag).to be_a(Float).and be_between(-range.end, range.end)
          expect(c.abs.round(6)).to be_between(range.begin, range.end)

          equal_count += 1 if c.real == c.imag

          min_arg = c.arg if c.arg < min_arg
          max_arg = c.arg if c.arg > max_arg

          min_abs = c.abs if c.abs < min_abs
          max_abs = c.abs if c.abs > max_abs
        end

        # Ensure real and imaginary values differ
        expect(equal_count).to be < 10

        # Ensure we're staying within the unit circle
        expect(min_abs.round(6)).to be_between(range.begin, range.begin + (range.end - range.begin) * 0.1)
        expect(max_abs.round(6)).to be_between(range.begin + (range.end - range.begin) * 0.9, range.end)

        # Ensure we're using the full range of angles
        expect((max_arg - min_arg) / Math::PI).to be_between(1.8, 2)
      end
    end

    it 'can specify the numeric type of rectangular coordinate complex values' do
      equal_count = 0

      1000.times do
        c = MB::M.random_value(1..500, complex: true)
        expect(c).to be_a(Complex)
        expect(c.real).to be_a(Integer).and be_between(1, 500)
        expect(c.imag).to be_a(Integer).and be_between(1, 500)
        equal_count += 1 if c.real == c.imag

        c = MB::M.random_value(1r..5r, complex: true)
        expect(c).to be_a(Complex)
        expect(c.real).to be_a(Rational).and be_between(1, 5)
        expect(c.imag).to be_a(Rational).and be_between(1, 5)
        equal_count += 1 if c.real == c.imag

        c = MB::M.random_value(-0.5..2.0, complex: true)
        expect(c).to be_a(Complex)
        expect(c.real).to be_a(Float).and be_between(-0.5, 2.0)
        expect(c.imag).to be_a(Float).and be_between(-0.5, 2.0)
        equal_count += 1 if c.real == c.imag
      end

      # Ensure real and imaginary values differ
      expect(equal_count).to be < 10
    end

    pending 'edge cases like using different types for each endpoint of a range'
  end
end
