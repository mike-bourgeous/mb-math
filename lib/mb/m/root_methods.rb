module MB
  module M
    # Methods for finding the roots of polynomials.
    module RootMethods
      # The default number of iterations to try in #find_one_root before giving
      # up.
      FIND_ONE_ROOT_DEFAULT_ITERATIONS = 100

      # The default distance to a root for #find_one_root to consider as
      # "equal".
      FIND_ONE_ROOT_DEFAULT_RANGE = 1e-13

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

      # This method tries to find one approximate root of the given block, if
      # the block represents a differentiable function of one variable.  The
      # +guess+ (a Numeric, whether real or complex) is used as a starting
      # point for iteration.  The optional +:min_real+, +:max_real+,
      # +:min_imag+, and +:max_imag+ parameters place lower and upper bounds on
      # the real and imaginary parts of the root search.
      #
      # A central finite difference approximation of Newton's method is used
      # for finding the root, which will result in many nearby values being
      # yielded to the block in an unspecified order.
      #
      # Example:
      #   find_one_root(2) { |x| x ** 2 - 1 }
      #   # => 1
      #   find_one_root(-2) { |x| x ** 2 - 1 }
      #   # => -1
      #
      # See https://en.wikipedia.org/wiki/Newton%27s_method
      # See https://en.wikipedia.org/wiki/Finite_difference
      # See https://en.wikipedia.org/wiki/Secant_method
      def find_one_root(
        guess,
        min_real: nil, max_real: nil,
        min_imag: nil, max_imag: nil,
        iterations: FIND_ONE_ROOT_DEFAULT_ITERATIONS,
        range: FIND_ONE_ROOT_DEFAULT_RANGE,
        &block
      )
        diff_delta = 1e-6

        x = guess
        y = yield x
        step = range * 100
        yprime = step

        # Finite differences
        iterations.times do |i|
          puts "  i=#{i} x=#{x} y=#{y} step=#{step}" # XXX

          break if y.abs <= range && step.abs <= range * 2 && i >= 5

          yleft = yield (x - diff_delta)
          yright = yield (x + diff_delta)

          # Central finite difference derivative, falling back to forward
          yprime = (yright - yleft) / (2.0 * diff_delta)
          yprime = (yright - y) / diff_delta if yprime.abs < range

          break if yprime == 0

          step = y / yprime

          # Make sure our finite difference approximation isn't stepping too far
          if step.abs < diff_delta.abs && step.abs > 0
            # TODO: what does this look like for complex root finding?
            puts "  Changing diff_delta from #{diff_delta} to #{step.abs}" # XXX
            diff_delta = step.abs
          end

          # TODO: maybe Jump around if we are stuck on a zero derivative
          # yprime = rand(-diff_delta..diff_delta) if yprime == 0

          # TODO: maybe try a few random guesses if we run out of iterations

          puts "  yprime=#{yprime} step=#{step}" # XXX

          x -= step
          y = yield x
        end

        # Possible multiple root; try finding root of f(x)/f'(x) instead of f(x)
        if yprime < range ** 2 && step > range
          puts "Trying multiple root method"

          x = find_one_root(x, min_real: min_real, max_real: max_real, min_imag: min_imag, max_imag: max_imag, iterations: iterations, range: range) { |v|
            yleft = yield (x - diff_delta)
            yright = yield (x + diff_delta)
            yprime = (yright - yleft) / (2.0 * diff_delta)

            (yield x) / yprime
          }

          y = yield x
        end

        # Secant method
        if y.abs > range || step.abs > range
          puts "Trying secant method"

          x = -x
          y = yield x
          x2 = guess
          y2 = yield x2
          step = range * 100

          iterations.times do |i|
            puts "  i=#{i} x=#{x} y=#{y} x2=#{x2} y2=#{y2} step=#{step}" # XXX

            break if y.abs <= range && step.abs <= range * 2 && i >= 5

            xnext = (x2 * y - x * y2) / (y - y2)
            step = xnext - x

            y2 = y
            x2 = x
            x = xnext

            y = yield x
          end
        end

        raise "Failed to converge within #{range} after #{iterations} iterations with x=#{x} y=#{y} step=#{step}" if y.abs > range || step > range

        x
      end
    end
  end
end
