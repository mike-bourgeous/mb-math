module MB
  module M
    # Methods for finding the roots of polynomials.
    module RootMethods
      # Methods to compute root-finding-related functions from a proc, such as
      # an approximate derivative.
      module RootProcExtensions
        # Returns a new proc which calculates an approximate derivative of this
        # proc, if this proc is a numerical function of one input and output
        # variable.
        #
        # TODO: consider a name more likely to be unique?
        #
        # :n - The order of the derivative (1 for first derivative, 2 for
        #      second, etc.)
        # :h - The relative scale to use for the finite difference (d = x * h
        #      if x is nonzero).  The default, 1e-5, provides close to the
        #      lowest error in most cases.
        def prime(n: 1, h: 1e-5)
          raise 'Can only create a derivative for arity=1 procs' unless arity == 1
          raise 'N must be a positive integer' unless n.is_a?(Integer) && n > 0

          # TODO: figure out an iterative way to do this
          base = n == 1 ? self : prime(n: n - 1, h: h)

          # TODO: look into the complex-step approximation
          # See https://mdolab.engin.umich.edu/wiki/guide-complex-step-derivative-approximation

          ->(x) {
            delta = x * h
            delta = Float::EPSILON if delta == 0
            yleft = base.call(x - delta)
            yright = base.call(x + delta)

            puts "yleft=#{yleft} yright=#{yright} x=#{x} delta=#{delta}" # XXX
            (yright - yleft) / (delta * 2)
          }
        end
      end

      Proc.include(RootProcExtensions)

      # The default number of iterations to try in #find_one_root before giving
      # up.
      FIND_ONE_ROOT_DEFAULT_ITERATIONS = 150

      # The default tolerance for slope per iteration and distance to root for
      # #find_one_root.
      FIND_ONE_ROOT_DEFAULT_TOLERANCE = 1e-13

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
      # +:iterations+ controls how many times to iterate for each method
      # (finite difference, secant, and multiple-root) before giving up on
      # convergence.
      #
      # +:tolerance+ controls the definition of success.  Both the increment
      # per iteration and the function's value must be below this value (or a
      # value derived from this value).
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
        tolerance: FIND_ONE_ROOT_DEFAULT_TOLERANCE,
        indent: 0,
        &block
      )
        prefix = '  ' * indent

        f = ->(x) {
          y = yield x
          puts "#{prefix}      f_#{indent}(#{x})=#{y}"
          y
        }

        f_prime = f.prime

        x = guess
        x = x.to_f if x.is_a?(Integer)
        y = f.call(x)
        y = y.to_f if y.is_a?(Integer)
        step = tolerance * 100
        yprime = step

        # TODO: implement min/max clamping

        # Finite differences
        puts "#{prefix}\e[1;32mFinite differences\e[0m"
        iterations.times do |i|
          puts "#{prefix}  i=#{i} x=#{x} y=#{y} step=#{step}" # XXX

          break if y.abs <= tolerance && step.abs <= tolerance * 2 && i >= 5

          yprime = f_prime.call(x)
          if yprime == 0
            puts "#{prefix}  y'(#{x}) is zero; finding a new guess"
            r = Random.new(x.to_s.delete('[^0-9]').to_i)
            iterations.times do |j|
              # TODO: base range on min..max bounds as well
              new_x = r.rand(0.9..1.1) * x
              new_y = f.call(new_x)
              puts "#{prefix}    guessing j=#{j} new_x=#{new_x}, getting new_y=#{new_y}"
              if new_y.abs < y.abs
                x, y = new_x, new_y if new_y.abs < y.abs
                puts "#{prefix}    \e[32mnow x=#{x} y=#{y} yprime=#{f_prime.call(x)}\e[0m"
              end
            end

            next
          end

          step = -y / yprime

          puts "#{prefix}  yprime=#{yprime} step=#{step}" # XXX

          # y / yprime will be infinity if yprime is zero so we can't continue
          break if yprime == 0

          # TODO: maybe try a few random guesses if we run out of iterations

          x += step
          y = f.call(x)
        end

        # Possible multiple root; try finding root of f(x)/f'(x) instead of f(x)
        if yprime.abs < tolerance ** 2 && y != 0 && indent == 0
          puts "#{prefix}\e[1;33mTrying multiple root method\e[0m"

          new_x = find_one_root(x, min_real: min_real, max_real: max_real, min_imag: min_imag, max_imag: max_imag, iterations: iterations, tolerance: tolerance, indent: indent + 1) { |v|
            puts "#{prefix}    Evaluating g(#{v})" # XXX

            f.call(v) / f_prime.call(v)
          }

          new_y = f.call(new_x)
          if new_y.abs < y.abs
            puts "#{prefix}  \e[1;32mMultiroot got f(#{new_x})=#{new_y}\e[0m"
            x = new_x
            y = new_y
          else
            puts "#{prefix}  \e[31mThis got worse\e[0m"
          end
        end

        # Secant method
        # TODO: none of the specs iterate with this method; find a case that needs this method, or remove this code
        # TODO: could reduce iterations within each method and cycle through
        # the four methods (finite difference, random search, multi-root
        # finite difference, secant) until we find a root
        if y.abs > tolerance || step.abs > tolerance
          puts "#{prefix}\e[1;35mTrying secant method\e[0m"

          x = -x
          y = f.call(x)
          x2 = guess
          y2 = f.call(x2)
          step = tolerance * 100

          iterations.times do |i|
            puts "#{prefix}  secant i=#{i} x=#{x} y=#{y} x2=#{x2} y2=#{y2} step=#{step}" # XXX

            break if y.abs <= tolerance && step.abs <= tolerance * 2 && i >= 5

            xnext = (x2 * y - x * y2) / (y - y2)
            step = xnext - x

            break if step.abs < tolerance.abs ** 2

            y2 = y
            x2 = x
            x = xnext

            y = f.call(x)
          end
        end

        raise "Failed to converge within #{tolerance} after #{iterations} iterations with x=#{x} y=#{y} step=#{step}" if y.abs > tolerance || step.abs > tolerance

        x
      end
    end
  end
end
