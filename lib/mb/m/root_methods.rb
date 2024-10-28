module MB
  module M
    # Methods for finding the roots of polynomials.
    module RootMethods
      # Returns an array with the two roots of a quadratic equation with the
      # given coefficients, whether the roots are real- or complex-valued.
      # Returns real-valued types (not Complex) for real-valued roots whenever
      # possible, even if some of the coefficients are complex resulting in one
      # real and one complex root.
      #
      # If +a+ is zero and +b+ is nonzero, then a single-element array is
      # returned with the one root of the corresponding linear equation.
      #
      # Raises RangeError if both +a+ and +b+ are zero.
      def quadratic_roots(a, b, c)
        raise RangeError, 'A or B must be nonzero' if a == 0 && b == 0 # Horizontal line

        return [1.0 * -c / b] if a == 0 # Linear equation (1.0 ensures float math)

        dsq = b * b - 4.0 * a * c

        # Checking if the number is complex is faster than always calling CMath.sqrt
        disc = (dsq.is_a?(Complex) || dsq < 0) ? CMath.sqrt(dsq) : Math.sqrt(dsq)

        denom = 2.0 * a

        r1 = ((-b + disc) / denom)
        r2 = ((-b - disc) / denom)

        r1 = r1.real if r1.is_a?(Complex) && r1.imag == 0
        r2 = r2.real if r2.is_a?(Complex) && r2.imag == 0

        [r1, r2]
      end
    end
  end
end
