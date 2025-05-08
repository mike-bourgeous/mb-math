RSpec.describe('mb-math RSpec matchers', aggregate_failures: false) do
  describe('all_be_within') do
    it 'fails if array lengths differ' do
      expect {
        expect(Numo::SFloat[1]).to all_be_within(0).of_array(Numo::SFloat[1, 2])
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /lengths differ/)
    end

    it 'fails if any elements are NaN' do
      expect {
        expect(Numo::SFloat[1, Float::NAN]).to all_be_within(1).of_array(Numo::SFloat[1, 2])
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /not a number/)
      expect {
        expect(Numo::SFloat[1, 2]).to all_be_within(1).of_array(Numo::SFloat[1, Float::NAN])
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /not a number/)
    end

    it 'passes if arrays are equal' do
      expect {
        expect(Numo::SFloat[1, 2]).to all_be_within(0).of_array(Numo::SFloat[1, 2])
      }.not_to raise_error
      expect {
        expect(Numo::SFloat[1, 2]).to all_be_within(0.001).of_array(Numo::SFloat[1, 2])
      }.not_to raise_error
    end

    it 'passes if arrays are within tolerance' do
      expect {
        expect(Numo::SFloat[0, 1]).to all_be_within(0.5).of_array(Numo::SFloat[0.5, 0.5])
      }.not_to raise_error
      expect {
        expect(Numo::SFloat[0.001, 0.002]).to all_be_within(0.005).of_array(Numo::SFloat[0, 0])
      }.not_to raise_error
    end

    it 'can compare complex values' do
      expect {
        expect(Numo::SComplex[0.25i, 1i]).to all_be_within(0.5).of_array(Numo::SComplex[0.25, 0.25+0.75i])
      }.not_to raise_error
      expect {
        expect(Numo::SComplex[0.001i, 0.002 + 0.002i]).to all_be_within(0.005).of_array(Numo::SFloat[0, 0])
      }.not_to raise_error
    end

    it 'fails if values are outside of tolerance' do
      expect {
        expect(Numo::SFloat[-1, 1]).to all_be_within(0.4999).of_array(Numo::SFloat[0.5, 0.5])
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /the maximum.*index 0/)

      expect {
        expect(Numo::SFloat[0.001, 0.002]).to all_be_within(0.0005).of_array(Numo::SFloat[0, 0])
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /the maximum/)

      expect {
        expect(Numo::SComplex[0.001i, 0.002 + 0.002i]).to all_be_within(0.0005).of_array(Numo::SFloat[0, 0])
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /the maximum.*index 1/)
    end

    it 'can compare Ruby Arrays to other Arrays and to Numo::NArrays' do
      expect {
        expect([1, 2, 3]).to all_be_within(10).of_array(Numo::SFloat[0, 0, 0])
      }.not_to raise_error

      expect {
        expect([1, 2, 3]).to all_be_within(10).of_array([0, 0, 0])
      }.not_to raise_error

      expect {
        expect(Numo::DComplex[1, 2, 3]).to all_be_within(10).of_array([0, 0, 5i])
      }.not_to raise_error
    end

    it 'can compare arrays to numbers' do
      expect {
        expect([1, 2]).to all_be_within(1).of_array(1)
      }.not_to raise_error
    end

    it 'can compare empty arrays' do
      expect {
        expect([]).to all_be_within(0).of_array([])
      }.not_to raise_error
      expect {
        expect(Numo::SFloat[]).to all_be_within(0).of_array(Numo::DComplex[])
      }.not_to raise_error
    end

    describe '.sigfigs' do
      it 'compares leading digits instead of absolute differences for a match' do
        expect {
          expect(Numo::SComplex[0.00101i, 0.00201]).to all_be_within(2).sigfigs.of_array(Numo::SComplex[0.001i, 0.002])
        }.not_to raise_error

        expect {
          expect(Numo::SFloat[12345]).to all_be_within(4).sigfigs.of_array(Numo::SFloat[12347])
        }.not_to raise_error
      end

      it 'includes the significant figures in the message for a non-match' do
        expect {
          expect(Numo::SComplex[0.001i, 0.002 + 0.002i]).to all_be_within(3).sigfigs.of_array(Numo::SFloat[1, 1])
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /3 significant figures/)

        expect {
          expect(Numo::SFloat[12345]).to all_be_within(4).sigfigs.of_array(Numo::SFloat[12348])
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /4 significant figures/)

        expect {
          expect(Numo::SFloat[99995]).to all_be_within(5).sigfigs.of_array(Numo::SFloat[99989])
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /5 significant figures/)

        expect {
          expect(Numo::SFloat[12345, 12346]).to all_be_within(5).sigfigs.of_array(Numo::SFloat[12349, 12340])
        }.to raise_error
      end

      it 'can compare zero to zero' do
        expect {
          expect(Numo::SComplex[0]).to all_be_within(2).sigfigs.of_array(Numo::SFloat[0])
        }.not_to raise_error
      end
    end
  end
end
