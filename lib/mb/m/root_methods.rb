require 'bigdecimal'

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

          # TODO: look into the complex-step derivative approximation
          # See https://mdolab.engin.umich.edu/wiki/guide-complex-step-derivative-approximation

          ->(x) {
            delta = x * h
            delta = Float::EPSILON if delta == 0
            yleft = base.call(x - delta)
            yright = base.call(x + delta)

            puts "yleft=#{yleft} yright=#{yright} x=#{x} delta=#{delta}" if $DEBUG # XXX
            (yright - yleft) / (delta * 2)
          }
        end
      end
      Proc.include(RootProcExtensions)

      # Raised when #find_one_root does not find a root
      class ConvergenceError < RangeError; end

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

        return [convert_down(-c.quo(b))] if a == 0 # Linear equation

        disc = kind_sqrt(b * b - 4 * a * c)

        denom = 2 * a

        r1 = (-b + disc).quo(denom)
        r2 = (-b - disc).quo(denom)

        [convert_down(r1), convert_down(r2)]
      end

      # Like Math.sqrt but preserves Rationals.  Inspired by the mathn gem's
      # implementation of sqrt.  Used by #quadratic_roots.
      def kind_sqrt(v)
        v = convert_down(v)

        case
        when v.is_a?(Complex)
          # https://math.stackexchange.com/questions/4760927/calculating-the-exact-square-root-of-a-complex-number-with-rational-components#comment10107923_4760927
          re = v.real
          im = v.imag
          abs = kind_sqrt(re * re + im * im)

          sgn = im < 0 ? -1 : 1
          x = kind_sqrt((re + abs).quo(2))
          y = kind_sqrt((-re + abs).quo(2))

          # TODO: if I wanted to get _really_ crazy, I could introduce a
          # Radical numeric type to preserve exact answers even further, and
          # maybe even an Algebraic numeric type
          r = Complex(x, sgn * y)

        when v < 0
          r = Complex(0, kind_sqrt(-v))

        when v.is_a?(Rational)
          r = kind_sqrt(v.numerator).quo(kind_sqrt(v.denominator))

        when v.is_a?(Integer)
          r = Integer.sqrt(v)
          r = r * r == v ? r : Math.sqrt(v)

        when v.is_a?(Float)
          r = Math.sqrt(v)

        when v.is_a?(BigDecimal)
          # TODO: use BigDecimal / BigMath more
          r = v.sqrt(MB::M.max(v.precision, 64))

        else
          r = v ** 0.5
        end

        convert_down(r)
      end

      # This method tries to find one approximate root of a differentiable
      # function of one variable using a collection of different methods to try
      # to avoid getting stuck: an approximation of Newton's method, a random
      # search, the secant method, and a variant of the preceding for possible
      # multiple roots (e.g. x ** 5 has five roots at zero).
      #
      # The given block must accept one Numeric parameter and return a Numeric
      # result (TODO: this could potentially be updated to operate on matrices
      # or similar).
      #
      # The +guess+ (a Numeric, whether real or complex) is used as a starting
      # point for iteration.  The guess should be complex to find a complex
      # root.
      #
      # The optional +:real_range+ and +:imag_range+ parameters place lower and
      # upper bounds on the real and imaginary parts of the root search.  Open
      # ended ranges are supported (TODO: support ranges in the first place).
      #
      # +:iterations+ controls how many times to iterate for each method
      # (finite difference, random guess, secant, and multiple-root) before
      # giving up on the search.
      #
      # +:loops+ controls how many times to repeat the collection of methods to
      # try to find and refine a root.
      #
      # +:tolerance+ controls the definition of success.  Both the increment
      # per iteration and the function's value must be below this value (or a
      # value derived from this value) at the end of all loops and iterations.
      #
      # Raises ConvergenceError if the value of the function or the last update
      # step are larger than +tolerance+ after all loops.
      #
      # Example:
      #   find_one_root(2) { |x| x ** 2 - 1 }
      #   # => 1
      #   find_one_root(-2) { |x| x ** 2 - 1 }
      #   # => -1
      #
      #   # With a callable instead of a block
      #   find_one_root(2, ->(x) { x - 1 })
      #   # => 1
      #
      # See https://en.wikipedia.org/wiki/Newton%27s_method
      # See https://en.wikipedia.org/wiki/Finite_difference
      # See https://en.wikipedia.org/wiki/Secant_method
      def find_one_root(
        guess,
        func = nil,
        real_range: nil,
        imag_range: nil,
        iterations: FIND_ONE_ROOT_DEFAULT_ITERATIONS,
        loops: 3,
        tolerance: FIND_ONE_ROOT_DEFAULT_TOLERANCE,
        depth: 0,
        prefix: nil,
        &block
      )
        prefix ||= '  ' * depth

        # TODO: maybe use the Newton's method implementation from BigDecimal/BigMath

        raise ArgumentError, "Pass only a callable function object, or a block; not both" if func && block_given?

        f = func || ->(x) {
          y = yield x
          puts "#{prefix}      f_#{depth}(#{x})=#{y}" if $DEBUG
          y
        }

        f_prime = f.prime

        x = guess
        x = x.to_f if x.is_a?(Integer)
        y = f.call(x)
        y = y.to_f if y.is_a?(Integer)
        yprime = f_prime.call(x)
        prev_x = x
        prev_y = y

        x_gain = 100 * tolerance
        y_gain = 100 * tolerance

        # TODO: implement min/max clamping
        # FIXME: bail faster if we hit nan or infinity anywhere
        # TODO: do something about indeterminate forms (0 / 0) in the multi-root function

        last_loop = 0

        loops.times do |l|
          last_loop = l
          MB::U.headline("\e[1mLoop #{l}\e[0m", prefix: prefix) if $DEBUG

          MB::U.headline("\e[1;36mTrying finite differences approximation\e[0m", prefix: prefix) if $DEBUG
          new_x, new_y = approx_newton_root(x, f: f, f_prime: f_prime, real_range: real_range, imag_range: imag_range, iterations: iterations, tolerance: tolerance, prefix: "#{prefix}  ")
          if new_y.abs < y.abs || (new_y.abs.to_f.finite? && !y.abs.to_f.finite?)
            puts "#{prefix}  \e[36mapprox \e[32mImprovement! (x,y=#{x},#{y} new_x,new_y=#{new_x},#{new_y}\e[0m" if $DEBUG
            step = new_x - x
            x, y = new_x, new_y
          else
            puts "#{prefix}  \e[36mapprox \e[33mY did not improve (x,y=#{x},#{y} new_x,new_y=#{new_x},#{new_y})\e[0m" if $DEBUG
          end

          # Exit early if we have an exact root
          puts "#{prefix}\e[32mExiting after approx with an exact root at x=#{x}\e[0m" if y == 0 if $DEBUG # XXX
          return x if y == 0

          # Try random shifts in case we are stuck.  The random seed is chosen
          # from the current X to make it deterministic.
          MB::U.headline("\e[1;35mTrying random guesses\e[0m", prefix: prefix) if $DEBUG

          new_x, new_y = random_guess_root(x, f: f, f_prime: f_prime, real_range: real_range, imag_range: imag_range, iterations: iterations, tolerance: tolerance, prefix: "#{prefix}  ")
          if new_y.abs < y.abs || (new_y.abs.to_f.finite? && !y.abs.to_f.finite?)
            puts "#{prefix}  \e[35mrandom \e[32mImprovement! (x,y=#{x},#{y} new_x,new_y=#{new_x},#{new_y}\e[0m" if $DEBUG
            step = new_x - x
            x, y = new_x, new_y
          else
            puts "#{prefix}  \e[35mrandom \e[33mY did not improve (x,y=#{x},#{y} new_x,new_y=#{new_x},#{new_y})\e[0m" if $DEBUG
          end

          # Exit early if we have an exact root
          puts "#{prefix}\e[32mExiting after random with an exact root at x=#{x}\e[0m" if y == 0 if $DEBUG # XXX
          return x if y == 0

          # Possible multiple root; try finding root of f(x)/f'(x) instead of f(x)
          yprime = f_prime.call(x)
          if yprime.abs < tolerance ** 2 && y != 0 && (step.nil? || step.abs > tolerance ** 2) && depth < 2
            MB::U.headline("#{prefix}\e[1;34mTrying multiple root method at depth=#{depth}\e[0m", prefix: prefix) if $DEBUG

            new_x, new_y = multi_root(x, f: f, f_prime: f_prime, real_range: real_range, imag_range: imag_range, iterations: iterations, tolerance: tolerance, depth: depth, prefix: "#{prefix}  ")
            if new_y.abs < y.abs || (new_y.abs.to_f.finite? && !y.abs.to_f.finite?)
              puts "#{prefix}  \e[34mmultiroot \e[32mImprovement! (x,y=#{x},#{y} new_x,new_y=#{new_x},#{new_y}\e[0m" if $DEBUG
              step = new_x - x
              x, y = new_x, new_y
            else
              puts "#{prefix}  \e[34mmultiroot \e[33mY did not improve (x,y=#{x},#{y} new_x,new_y=#{new_x},#{new_y})\e[0m" if $DEBUG
            end
          end

          # Exit early if we have an exact root
          puts "#{prefix}\e[32mExiting after multiroot with an exact root at x=#{x}\e[0m" if y == 0 if $DEBUG # XXX
          return x if y == 0

          # Secant method
          # TODO: none of the specs iterate with this method; find a case that needs this method, or remove this code
          if y.abs > tolerance ** 2 || step.nil? || step.abs > tolerance ** 2
            MB::U.headline("\e[1;35mTrying secant method\e[0m", prefix: prefix) if $DEBUG

            new_x, new_y = secant_root(x, guess, f: f, f_prime: f_prime, real_range: real_range, imag_range: imag_range, iterations: iterations, tolerance: tolerance, prefix: "#{prefix}  ")
            if new_y.abs < y.abs || (new_y.abs.to_f.finite? && !y.abs.to_f.finite?)
              puts "#{prefix}  \e[35msecant \e[32mImprovement! (x,y=#{x},#{y} new_x,new_y=#{new_x},#{new_y}\e[0m" if $DEBUG
              step = new_x - x
              x, y = new_x, new_y
            else
              puts "#{prefix}  \e[35msecant \e[33mY did not improve (x,y=#{x},#{y} new_x,new_y=#{new_x},#{new_y})\e[0m" if $DEBUG
            end
          end

          # Exit early if we have an exact root
          puts "#{prefix}\e[32mExiting after secant with an exact root at x=#{x}\e[0m" if y == 0 if $DEBUG # XXX
          return x if y == 0

          # Creeping method
          MB::U.headline("\e[1;38;5;150mTrying creeping method\e[0m", prefix: prefix) if $DEBUG
          new_x, new_y = creeping_root(x, f: f, f_prime: f_prime, real_range: real_range, imag_range: imag_range, iterations: iterations, tolerance: tolerance, prefix: "#{prefix}  ")
          if new_y.abs < y.abs || (new_y.abs.to_f.finite? && !y.abs.to_f.finite?)
            puts "#{prefix}  \e[38;5;150mcreeping \e[32mImprovement! (x,y=#{x},#{y} new_x,new_y=#{new_x},#{new_y}\e[0m" if $DEBUG
            step = new_x - x
            x, y = new_x, new_y
          else
            puts "#{prefix}  \e[38;5;150mcreeping \e[33mY did not improve (x,y=#{x},#{y} new_x,new_y=#{new_x},#{new_y})\e[0m" if $DEBUG
          end

          # Exit early if we have an exact root
          puts "#{prefix}\e[32mExiting after creeping with an exact root at x=#{x}\e[0m" if y == 0 if $DEBUG # XXX
          return x if y == 0

          # Rounding method
          MB::U.headline("\e[1;38;5;117mTrying rounding method\e[0m", prefix: prefix) if $DEBUG
          new_x, new_y = rounding_root(x, f: f, prefix: "#{prefix}  ")
          if new_y && (new_y.abs <= y.abs || (new_y.abs.to_f.finite? && !y.abs.to_f.finite?))
            puts "#{prefix}  \e[38;5;117mrounding \e[32mImprovement! (x,y=#{x},#{y} new_x,new_y=#{new_x},#{new_y}\e[0m" if $DEBUG
            step = new_x - x
            x, y = new_x, new_y
          else
            puts "#{prefix}  \e[38;5;117mrounding \e[33mY did not improve (x,y=#{x},#{y} new_x,new_y=#{new_x},#{new_y})\e[0m" if $DEBUG
          end

          # Exit early if we have an exact root
          puts "#{prefix}\e[32mExiting after rounding with an exact root at x=#{x}\e[0m" if y == 0 if $DEBUG # XXX
          return x if y == 0

          x_gain = x - prev_x
          y_gain = y.abs - prev_y.abs
          if x_gain.abs < tolerance ** 2 || y_gain.abs < tolerance ** 2
            puts "#{prefix}\e[33mImprovement is very slow on loop #{l} (x_gain=#{x_gain} y_gain=#{y_gain})\e[0m" if $DEBUG
          elsif y_gain > 0
            puts "#{prefix}\e[33mY got worse on loop #{l} (x_gain=#{x_gain} y_gain=#{y_gain} x,y=#{x},#{y} prevx,prevy=#{prev_x},#{prev_y}\e[0m" if $DEBUG
          end

          # Stop if we made no progress
          if x_gain == 0
            puts "#{prefix}  \e[31mNo progress made on loop #{last_loop} at depth #{depth}\e[0m" if $DEBUG

            if depth < 0 # XXX
              puts "trying rounding imag at depth #{depth}"
              new_x = find_one_root(Complex(x.real, y.real.round(6)), f, depth: depth + 1)
              new_y = f.call(new_x)

              if new_y.abs >= y.abs
                puts "trying rounding real at depth #{depth}"
                new_x = find_one_root(Complex(x.real.round(6), y.real), f, depth: depth + 1)
                new_y = f.call(new_x)
              end

              if new_y.abs >= y.abs
                puts "trying rounding at depth #{depth}"
                new_x = find_one_root(MB::M.round(x, 6), f, depth: depth + 1)
                new_y = f.call(new_x)
              end

              if new_y.abs < y.abs
                puts "somehow that worked at depth #{depth}"

                # XXX require 'pry-byebug'; binding.pry if depth == 0 # XXX

                x = new_x
                y = new_y

                next # XXX
              end
            end

            break
          end

          # Stop if we've reached "good enough"
          if y.abs < tolerance ** 2 && step && step.abs < tolerance ** 2 && x_gain.abs < tolerance ** 2
            puts "Good enough: y #{y.abs} < #{tolerance ** 2}; step #{step.abs} < #{tolerance ** 2}; xg #{x_gain.abs} < #{tolerance ** 2}"
            break
          end

          prev_x = x
          prev_y = y
        end

        # TODO: maybe do some rounding here to see if we can get an integer

        # FIXME: x_gain might be large if loops is 1
        if depth == 0 && (y.abs > tolerance || x_gain.abs > tolerance)
          raise ConvergenceError, "Failed to converge after #{last_loop} loops within #{tolerance} with x=#{x} y=#{y} x_gain=#{x_gain} y_gain=#{y_gain} f=#{f}"
        end

        x
      end

      private

      # The finite differences approximation of Newton's method used by
      # #find_one_root.  Returns the new value for X and Y after at most
      # +:iterations+ steps.
      def approx_newton_root(x_orig, f:, f_prime:, real_range:, imag_range:, iterations:, tolerance:, prefix:)
        y_orig = f.call(x_orig)
        yprime_orig = f_prime.call(x_orig)

        x = x_orig
        y = y_orig
        yprime = yprime_orig

        step = nil

        x_prev = x

        # Finite differences
        iterations.times do |i|
          puts "#{prefix}\e[36mapprox i=#{i} x=#{x} y=#{y} step=#{step}\e[0m" if $DEBUG # XXX
          break if y == 0 || step == 0

          if yprime == 0 || !yprime.abs.to_f.finite?
            puts "#{prefix}  \e[36mapprox i=#{i} yprime is #{yprime}; trying random guesses\e[0m" if $DEBUG
            x, y = random_guess_root(
              x,
              f: f,
              f_prime: f_prime,
              real_range: real_range,
              imag_range: imag_range,
              iterations: [10, iterations - i].max,
              tolerance: tolerance,
              prefix: "#{prefix}  \e[36mapprox i=#{i}\e[0m "
            )
          end

          step = -y / yprime

          x += step
          y = f.call(x)

          # Sometimes newton's gets stuck so try jiggling a very tiny amount
          x, y = creeping_root(
            x,
            f: f,
            f_prime: f_prime,
            real_range: real_range,
            imag_range: imag_range,
            iterations: 10,
            tolerance: tolerance,
            prefix: "#{prefix}  \e[36mapprox i=#{i}\e[0m "
          )

          yprime = f_prime.call(x)

          puts "#{prefix}  \e[36mapprox i=#{i} yprime=#{yprime} step=#{step}\e[0m" if $DEBUG # XXX

          x_diff = (x_prev - x).abs
          break if x_diff < tolerance ** 2

          x_prev = x
        end

        return x, y
      end

      # The random guesses method used by #find_one_root.  Returns the new
      # value for X and Y.
      def random_guess_root(x_orig, f:, f_prime:, real_range:, imag_range:, iterations:, tolerance:, prefix:)
        y_orig = f.call(x_orig)
        yprime_orig = f_prime.call(x_orig)

        x = x_orig
        y = y_orig

        r = Random.new(x.to_s.delete('[^0-9]').to_i)

        iterations.times do |j|
          # TODO: base range on min..max bounds and local slope as well
          new_x = rand_shift(r, x, 0.9..1.1, tolerance)
          new_y = f.call(new_x)
          puts "#{prefix}  \e[35mguessing j=#{j} new_x=#{new_x}, new_y=#{new_y}\e[0m" if $DEBUG
          if new_y.abs < y.abs || (new_y.abs.to_f.finite? && !y.abs.to_f.finite?)
            x, y = new_x, new_y
            yprime = f_prime.call(x)
            puts "#{prefix}  \e[32mnow x=#{x} y=#{y} yprime=#{yprime}\e[0m" if $DEBUG
          end
        end

        return x, y
      end

      # Method that tries shifting by a few floating point minimum increments
      # to see if Y improves.
      def creeping_root(x_orig, f:, f_prime:, real_range:, imag_range:, iterations:, tolerance:, prefix:)
        y_orig = f.call(x_orig)

        x = x_orig
        y = y_orig

        iterations.times do |i|
          improved = false

          # TODO: figure out why getting closer to a root sometimes makes Y worse.  Example:
          # roots = [-10, -1, 4, -6, 4, -1, 3] # polynomial spec integer random roots
          # f = MB::M::Polynomial.new(-9, -63, 585, 1935, -12780, -2844, 37152, 25920)
          # f.roots
          # ...
          # f2 = MB::M::Polynomial.new(
          #   -9,
          #   (-99-4.872711348481414e-07i),
          #   (189.0-7.30906702272212e-06i),
          #   (2691.0000000000005-1.9003574259077513e-05i),
          #   (-2015.9999999999964+6.967977228328423e-05i),
          #   (-10907.999999999989+0.00016957035492715347i),
          #   (-6479.999999999964+8.770880427266716e-05i)
          # )
          # find_one_root with x = (4.000000000000004-5.41412372053487e-08i)

          # TODO: this could go faster if the creep increments are only
          # computed when needed, if we first try the same direction as the
          # last improvement, and if we go to the next iteration after one or
          # two improvements instead of checking the entire list.
          complex_creep(x).each.with_index do |new_x, idx|
            new_y = f.call(new_x)
            if new_y.abs < y.abs || (new_y.real.abs < y.real.abs && new_y.imag.abs < y.imag.abs)
              puts "#{prefix}  \e[38;5;150mcreeping improvement found: i=#{i} idx=#{idx}(#{idx % 5},#{idx / 5}) new_x,new_y=#{new_x},#{new_y} from x,y=#{x},#{y}\e[0m" if $DEBUG
              improved = true
              x = new_x
              y = new_y
            end
          end

          break unless improved
        end

        return x, y
      end

      # The multiple-root method used by #find_one_root if Newton's method
      # seems to converge really slowly.  Returns the new value for X and Y.
      def multi_root(x_orig, f:, f_prime:, real_range:, imag_range:, iterations:, tolerance:, depth:, prefix:)
        y_orig = f.call(x_orig)

        x = find_one_root(x_orig, real_range: real_range, imag_range: imag_range, loops: 1, iterations: iterations, tolerance: tolerance, depth: depth + 1, prefix: "#{prefix}  \e[34mmultiroot\e[0m ") { |v|
          puts "#{prefix}    \e[34mmultiroot\e[0m Evaluating g(#{v})" if $DEBUG # XXX

          yg = f.call(v)
          ygp = f_prime.call(v)

          if ygp == 0
            puts "#{prefix}    \e[34mmultiroot\e[0m derivative is zero; trying second derivative" if $DEBUG

            yg2 = f_prime.call(v)
            ygp2 = f_prime.prime.call(v)

            if ygp2 == 0
              puts "#{prefix}    \e[34mmultiroot\e[0m second derivative is zero; just returning original function" if $DEBUG
              ygp = 1
            else
              yg = yg2
              ygp = ygp2
            end
          end

          g = yg / ygp

          puts "#{prefix}    \e[34mmultiroot\e[0m g=#{g} yg=#{yg} ygp=#{ygp}" if $DEBUG

          g
        }

        y = f.call(x)

        return x, y

      rescue ConvergenceError => e
        puts "#{prefix}  \e[34mmultiroot \e[33mNo convergence; returning original x and y (#{x_orig},#{y_orig}): #{e}" if $DEBUG

        return x_orig, y_orig
      end

      # The secant method used by #find_one_root if Newton's method and random
      # guesses aren't converging.  Returns the new value for X and Y.
      def secant_root(x_orig, x2, f:, f_prime:, real_range:, imag_range:, iterations:, tolerance:, prefix:)
        x = x_orig
        y = f.call(x)
        y2 = f.call(x2)
        step = tolerance * 100

        iterations.times do |i|
          puts "#{prefix}  secant i=#{i} x=#{x} y=#{y} x2=#{x2} y2=#{y2} step=#{step}" if $DEBUG # XXX

          break if y.abs <= tolerance && step.abs <= tolerance && i >= 5

          xnext = (x2 * y - x * y2) / (y - y2)
          step = xnext - x
          puts "#{prefix}    secant xnext=#{xnext} step=#{step}" if $DEBUG # XXX

          break if step.abs < tolerance.abs ** 2 || !xnext.abs.to_f.finite?

          y2 = y
          x2 = x
          x = xnext

          y = f.call(x)
        end

        return x, y
      end

      # Tries rounding to varying levels of precision to see if that improves
      # the zero.  This is kind of a cheat to be able to find integer roots.
      #
      # TODO: could also try continued fractions to find rational roots
      def rounding_root(x_orig, f:, prefix:)
        y_orig = f.call(x_orig)

        x = x_orig
        y = y_orig

        7.times do |i|
          new_x = MB::M.round(x, i + 3)
          new_y = f.call(new_x)

          puts "#{prefix}\e[38;5;117mrounding\e[0m trying #{new_x} getting #{new_y} at step #{i}" if $DEBUG

          x, y = new_x, new_y if new_x != x && new_y.abs <= y.abs

          break if y == 0
        end

        return x, y unless x == x_orig
      end

      # If +value+ is Complex, returns a randomly shifted value with a
      # different shift in the real and imaginary directions.  If +value+ is
      # real, returns a randomly shifted value within the range.
      #
      # The +range+ is a ratio of the existing values.  If a value is closer to
      # zero than the given +tolerance+ or is NaN or infinity, then instead of
      # a ratio, the range will be shifted to center around zero and sampled
      # directly.
      def rand_shift(random, value, range, tolerance)
        if value.is_a?(Complex)
          real = rand_shift(random, value.real, range, tolerance)
          imag = rand_shift(random, value.imag, range, tolerance)
          real + 1i * imag
        elsif !value.abs.to_f.finite? || value.abs < tolerance.abs
          puts "\e[33mComplex rand dodging a non-finite: #{value}\e[0m" if !value.abs.to_f.finite? if $DEBUG # XXX
          span = (range.end - range.begin) / 2
          random.rand(-span..span)
        else
          random.rand(range) * value
        end
      end

      # Returns an Array of values near the given value using tiny increments,
      # used by #creeping_root.
      def complex_creep(value)
        if value.is_a?(Complex)
          reals = complex_creep(value.real)
          imags = complex_creep(value.imag)
          reals.product(imags).map { |re, im| Complex(re, im) }
        else
          value = value.to_f
          [
            value + (10 * Float::EPSILON) * value,
            float_ulps(value, 2),
            value.next_float,
            value,
            value.prev_float,
            float_ulps(value, -2),
            value - (10 * Float::EPSILON) * value,
          ]
        end
      end

      # Moves +value+ up or down by +count+ units in the least precision using
      # Float#next_float and Float#prev_float.
      def float_ulps(value, count)
        if count > 0
          count.times do
            value = value.next_float
          end
        elsif count < 0
          (-count).times do
            value = value.prev_float
          end
        end

        value
      end
    end
  end
end
