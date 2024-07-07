RSpec.describe(MB::M::Plot::Function) do
  describe '#initialize' do
    it 'can build a simple expression from DSL' do
      f = MB::M::Plot::Function.new { x * y + 5 }
      expect(f.to_s).to eq('((x * y) + 5)')
    end
  end
end
