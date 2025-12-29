module MB
  module M
    # Methods related to the creation, modification, and use of matrices.
    module MatrixMethods
      # Uses Sylvester's construction, as documented on Wikipedia, to construct
      # a power-of-two-sized Hadamard matrix.  The elements of the returned
      # matrix will be either 1 or -1, and the rows will be orthogonal.
      #
      # Returns a row-major Array of Arrays.  To convert to a Matrix, use
      # `Matrix[*hadamard(n)]`.  To convert to a Numo::NArray, use e.g.
      # `Numo::SFloat.cast(hadamard(n))`.
      def hadamard(order)
        raise 'Order must be a power of two (e.g. 1, 2, 4, 8, 16, ...)' unless 2 ** Math.log2(order).floor == order

        case order
        when 1
          [[1]]

        when 2
          [[1, 1], [1, -1]]
        
        else
          prior_size = order / 2
          prior = hadamard(prior_size)

          top_half = prior.map { |p| p * 2 }
          bottom_half = prior.map { |p| p + p.map(&:-@) }

          top_half + bottom_half
        end
      end
    end
  end
end
