RSpec.describe(MB::M::VectorMethods, aggregate_failures: true) do
  describe '#reflect' do
    let(:cases) {
      [
        {
          vector: [1, 2, 3],
          normal: [1, 0, 0],
          result: [-1, 2, 3],
        },
        {
          vector: [1, 2, 3],
          normal: [0, 1, 0],
          result: [1, -2, 3],
        },
        {
          vector: [1, 2, 3],
          normal: [0, 0, 1],
          result: [1, 2, -3],
        },
        {
          vector: [1, 2, 3, 4],
          normal: [0, 0, 0, 4],
          result: [1, 2, 3, -4],
        },
        {
          vector: [-2, 5],
          normal: [1, 1],
          result: [-5, 2],
        },
        {
          # opposite normal, same plane
          vector: [-2, 5],
          normal: [-1, -1],
          result: [-5, 2],
        },
        {
          vector: [1, 2, 3, 4, 5],
          normal: [1, 1, 1, 1, 1],
          result: [-5, -4, -3, -2, -1],
        },
        {
          vector: [1, -2, 3, -4, 5],
          normal: [1, 1, 1, 1, 1],
          result: [-1r/5, -16r/5, 9r/5, -26r/5, 19r/5],
        },
      ]
    }

    shared_examples_for('planar reflection') do
      it 'returns the expected result for various test cases' do
        cases.each do |c|
          v = argmap.call(c[:vector])
          n = argmap.call(c[:normal])
          r = argmap.call(c[:result])

          expect(MB::M.reflect(v, n)).to all_be_within(1e-6).of_array(r)
        end
      end

      it 'returns the original value, within rounding error, when applied twice' do
        cases.each do |c|
          v = argmap.call(c[:vector])
          n = argmap.call(c[:normal])

          expect(MB::M.reflect(MB::M.reflect(v, n), n)).to all_be_within(1e-6).of_array(v)
        end
      end
    end

    context 'with Vector' do
      let(:argmap) { ->(d) { Vector[*d] } }
      it_behaves_like('planar reflection')
    end

    context 'with Numo::SFloat' do
      let(:argmap) { ->(d) { Numo::SFloat.cast(d) } }
      it_behaves_like('planar reflection')
    end

    context 'with Array' do
      let(:argmap) { ->(d) { d } }
      it_behaves_like('planar reflection')
    end

    context 'with Vector of Numo::SFloat' do
      let(:vec_4_9) {
        [
          Vector[1, 0, 1, 0],
          Vector[0, 1, 1, 0],
          Vector[-1, 1, -1, 0],
          Vector[0, 0, 0, 1],
          Vector[1, -1, -1, 1],
          Vector[0, 1, 0, -1],
          Vector[0, 0, 1, -1],
          Vector[0.1, 0.2, -0.3, -0.4],
          Vector[-1, 2, -3, 4],
        ]
      }

      let(:normal4) { Vector[0.5, -0.3, -1, 1].normalize }

      let(:vec_4_sfloat) {
        Vector[*vec_4_9.map(&:to_a).transpose.map(&Numo::SFloat.method(:cast))]
      }

      let(:vec_2_5) {
        Vector[
          Numo::SFloat[1, 1],
          Numo::SFloat[2, -2],
          Numo::SFloat[3, 3],
          Numo::SFloat[4, -4],
          Numo::SFloat[5, 5],
        ]
      }

      let(:norm5) { Vector[1, 1, 1, 1, 1] }
      let(:norm5_2) { Vector[1, -1, 2, -3, 4].normalize }

      it 'processes a vector of narrays as an array of vectors' do
        expect(MB::M.reflect(vec_2_5, norm5)).to all_be_within(1e-6).of_array(Vector[
          Numo::SFloat[-5, -1.0/5.0],
          Numo::SFloat[-4, -16.0/5.0],
          Numo::SFloat[-3, 9.0/5.0],
          Numo::SFloat[-2, -26.0/5.0],
          Numo::SFloat[-1, 19.0/5.0],
        ])
      end

      it 'returns to the original values (within rounding error) when applied twice' do
        expect(MB::M.reflect(MB::M.reflect(vec_2_5, norm5), norm5)).to all_be_within(1e-5).of_array(vec_2_5)
        expect(MB::M.reflect(MB::M.reflect(vec_2_5, norm5_2), norm5_2)).to all_be_within(1e-5).of_array(vec_2_5)
      end

      it 'produces the same result as operating on individual vectors' do
        vec_result = Vector[*vec_4_9.map { |v| MB::M.reflect(v, normal4).to_a }.transpose.map(&Numo::SFloat.method(:cast))]
        sf_result = MB::M.reflect(vec_4_sfloat, normal4)

        expect(MB::M.round(sf_result, 5)).to eq(MB::M.round(vec_result, 5))
      end
    end
  end
end
