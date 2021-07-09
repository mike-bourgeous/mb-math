module MB
  module M
    # Low-precision implementations of special mathematical functions and
    # related functions, such as the polylogarithm function and Riemann zeta
    # function.
    module SpecialFunctions
      # The polylogarithm function, useful for computing integrals of
      # logarithms.
      #
      # This implementation is based on a 2006 paper by R. E. Crandall.
      #
      # See https://cs.stackexchange.com/questions/124418/algorithm-to-calculate-polylogarithm/124420#124420
      # See https://www.reed.edu/physics/faculty/crandall/papers/Polylog.pdf
      # See https://en.wikipedia.org/wiki/Spence%27s_function
      def polylog(order, z, limit = nil)
        z = z.to_f if z.is_a?(Integer)

        case order
        when 1
          -CMath.log(1.0 - z)

        when 0
          z / (1.0 - z)

        when -1
          z / (1.0 - z) ** 2

        else
          case z
          when 1
            zeta(order)

          when -1
            -(1.0 - 2.0 ** (1.0 - order)) * zeta(order)

          else
            # TODO: Write a sum function that terminates when the summands
            # start growing relative to the previous summand?  Strangely when I
            # increase this limit tests start to fail.  Below 5 digits, tests fail,
            # above 12 digits, tests fail.
            #
            # https://en.wikipedia.org/wiki/Polylogarithm#Asymptotic_expansions
            # says "As usual, the summation should be terminated when the terms
            # start growing in magnitude."
            limit ||= (8 * Math.log2(10)).ceil

            if z.abs <= 0.5
              polylog_1_1(order, z, limit)
            elsif z.abs >= 2 && order > 0
              # Crandall(2006) does not have the order > 0 condition here, but
              # the right-hand side of equation 1.3 (#polylog_1_3) has a
              # factorial on the order.
              polylog_1_3(order, z, limit) - (-1) ** order * polylog_1_1(order, 1.0 / z, limit)
            elsif order > 0
              polylog_1_4(order, z, limit)
            else
              # Equation 1.5 from Crandall(2006) is replaced with this
              # polylog_neg expansion to handle negative orders.
              polylog_neg(order, z)
            end
          end
        end
      end

      # polylog(2, x)
      def dilog(x)
        polylog(2, x)
      end

      # Riemann zeta function, used in polylogarithm implementation.
      # This expansion comes from https://mathworld.wolfram.com/RiemannZetaFunction.html
      def zeta(s, limit = 35)
        1.0 / (1 - 2 ** (1.0 - s)) *
          limit.downto(0).sum { |n|
            (1.0 / 2.0 ** (n + 1)) *
              (0..n).sum { |k|
                (-1) ** k * n.choose(k) * (k + 1) ** -s # TODO: this is faster with n.to_f.choose(k.to_f), but it doesn't give the right answer for -10
            }
          }
      end

      # Bernoulli polynomials for polylogarithm.
      # See https://en.wikipedia.org/wiki/Bernoulli_polynomials#Explicit_formula
      def bernoulli_polynomial(n, x)
        n.downto(0).sum { |k|
          n.choose(k) * bernoulli_number(n - k) * x ** k
        }
      end

      # Bernoulli numbers for polylogarithm.
      # See https://mathworld.wolfram.com/BernoulliNumber.html
      # See https://en.wikipedia.org/wiki/Bernoulli_number#Explicit_definition
      def bernoulli_number(n)
        @bn ||= []
        @bn[n] ||= n.downto(0).sum { |k|
          1.0 / (k + 1) * k.downto(0).sum { |r|
            (-1) ** r * k.choose(r) * r ** n
          }
        }
      end

      # Harmonic numbers as described in Crandall(2006) for equation 1.4.
      def harmonic_number(q)
        q.downto(1).sum { |k| 1.0 / k }
      end

      # Eulerian number for #polylog_neg (not the same as Euler number).
      # See https://mathworld.wolfram.com/EulerianNumber.html
      def eulerian_number(n, k)
        (k+1).downto(0).sum { |j|
          (-1) ** j * (n + 1).choose(j) * (k - j + 1) ** n
        }
      end

      private

      # Equation 1.1 in Crandall(2006).
      def polylog_1_1(n, z, limit)
        limit.downto(1).sum { |k| z ** k / k ** n }
      end

      # Right side of equation 1.3 in Crandall(2006).
      def polylog_1_3(n, z, limit)
        s = -(2i * Math::PI) ** n / n.factorial * bernoulli_polynomial(n, CMath.log(z) / (2i * Math::PI))

        if z.imag < 0 || (z.imag == 0 && z.real >= 1)
          s -= 2i * Math::PI * CMath.log(z) ** (n - 1) / (n - 1).factorial
        end

        s
      end

      # Equation 1.4 in Crandall(2006).
      def polylog_1_4(n, z, limit)
        a = limit.downto(0).sum { |m|
          next 0 if (n - m) == 1 # sigma prime notation from the paper, skip infinite zeta(1)
          zeta(n - m) / m.factorial * CMath.log(z) ** m
        }
        b = CMath.log(z) ** (n - 1) / (n - 1).factorial * (harmonic_number(n - 1) - CMath.log(-CMath.log(z)))
        a + b
      end

      # Additional form of the polylogarithm to handle negative orders.
      # From https://mathworld.wolfram.com/Polylogarithm.html
      def polylog_neg(n, z)
        n = -n
        1.0 / (1 - z) ** (n + 1) * n.downto(0).sum { |i| eulerian_number(n, i) * z ** (n - i) }
      end
    end
  end
end
