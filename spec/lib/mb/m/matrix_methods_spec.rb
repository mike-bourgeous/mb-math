RSpec.describe(MB::M::MatrixMethods) do
  describe '#hadamard' do
    it 'raises an error for a non-power-of-two order' do
      expect { MB::M.hadamard(3) }.to raise_error(/power.*two/i)
    end

    it 'returns the expected order-4 matrix' do
      expect(MB::M.hadamard(4)).to eq([
        [1, 1, 1, 1],
        [1, -1, 1, -1],
        [1, 1, -1, -1],
        [1, -1, -1, 1],
      ])
    end

    for exponent in 0..10 do
      order = 1 << exponent
      it "can create an order-#{order} matrix with the expected properties" do
        h = MB::M.hadamard(order)
        m = Matrix[*m]
        sf = Numo::SFloat.cast(h)

        expect(Matrix[*m]).to be_symmetric
        expect(sf.minmax).to eq([-1, 1])
        expect(h.flatten.uniq.sort).to eq([-1, 1])
      end
    end
  end
end
