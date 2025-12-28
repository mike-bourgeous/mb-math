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

        # TODO: Vector of NArrays for array of vector processing
      ]
    }

    shared_examples_for('planar reflection') do
      it 'returns the expected result for various test cases' do
        cases.each do |c|
          v = argmap.call(c[:vector])
          n = argmap.call(c[:normal])
          r = argmap.call(c[:result])

          expect(MB::M.round(MB::M.reflect(v, n), 6)).to eq(MB::M.round(r, 6))
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
  end
end
