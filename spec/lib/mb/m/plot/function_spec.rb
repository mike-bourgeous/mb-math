RSpec.describe(MB::M::Plot::Function, :aggregate_failures) do
  describe '#initialize' do
    it 'can build a simple expression from DSL' do
      f = MB::M::Plot::Function.new { x * y + 5 }
      expect(f.to_s).to eq('((x * y) + 5)')
    end

    it 'can coerce numeric values for the DSL' do
      f = MB::M::Plot::Function.new { 1 + x }
      expect(f.to_s).to eq('(1 + x)')
    end
  end

  describe '#call' do
    it 'can evaluate a constant function' do
      f = MB::M::Plot::Function.new { 42 }
      expect(f.to_s).to eq('42')
      expect(f.call).to eq(42)
    end

    it 'can evaluate the function given values for independent variables' do
      f = MB::M::Plot::Function.new { 5 * x + y ** z }
      expect(f.to_s).to eq('((5 * x) + (y ** z))')
      expect(f.call(x: 10, y: 2, z: 4)).to eq(66)
    end

    it 'accepts a proc for independent variables' do
      f = MB::M::Plot::Function.new { q * 3 }
      expect(f.to_s).to eq('(q * 3)')
      expect(f.call(q: -> { 17 })).to eq(17 * 3)
    end
  end
end
