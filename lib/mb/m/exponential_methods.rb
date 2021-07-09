module MB
  module M
    # Functions relating to powers, exponents, and logarithms.
    module ExponentialMethods
      # The polylogarithm function, useful for computing integrals of
      # logarithms.
      #
      # This implementation is based on a 2006 paper by R. E. Crandall.
      #
      # See https://cs.stackexchange.com/questions/124418/algorithm-to-calculate-polylogarithm/124420#124420
      # See https://www.reed.edu/physics/faculty/crandall/papers/Polylog.pdf
      # See https://en.wikipedia.org/wiki/Spence%27s_function
      def polylog(order, z)
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
            ExponentialMethods.polylog_zeta(order)

          when -1
            -(1.0 - 2.0 ** (1.0 - order)) * ExponentialMethods.polylog_zeta(order)

          else
            limit = (10 * Math.log2(10)).ceil

            if z.abs <= 0.5
              ExponentialMethods.polylog_1_1(order, z, limit)
            elsif z.abs >= 2
              ExponentialMethods.polylog_1_3(order, z, limit) - (-1) ** order * ExponentialMethods.polylog_1_1(order, 1.0 / z, limit)
            elsif order > 0
              ExponentialMethods.polylog_1_4(order, z, limit)
            else
              ExponentialMethods.polylog_1_5(order, z, limit)
            end
          end
        end
      end

      # polylog(2, x)
      def dilog(x)
        polylog(2, x)
      end

      # Raises the given +value+ to the given +power+, but using the absolute
      # value function to prevent complex results.  Useful for waveshaping.
      def safe_power(value, power)
        if value.is_a?(Numo::NArray)
          return value.map { |v| safe_power(v, power) }
        end

        sign = value.positive? ? 1.0 : -1.0
        value.abs ** power * sign
      end

      # Equation 1.1 in Crandall(2006).
      def self.polylog_1_1(n, z, limit)
        limit.downto(1).sum { |k| z ** k / k ** n }
      end

      # Equation 1.4 in Crandall(2006).
      def self.polylog_1_4(n, z, limit)
        a = limit.downto(0).sum { |m|
          next 0 if (n - m) == 1 # sigma prime notation from the paper, skip infinite zeta(1)
          polylog_zeta(n - m) / m.factorial * CMath.log(z) ** m
        }
        b = CMath.log(z) ** (n - 1) / (n - 1).factorial * (polylog_harmonic(n - 1) - CMath.log(-CMath.log(z)))
        a + b
      end

      # Right side of equation 1.3 in Crandall(2006).
      def self.polylog_1_3(n, z, limit)
        s = -(2i * Math::PI) ** n / n.factorial * polylog_bernoulli_polynomial(n, CMath.log(z) / (2i * Math::PI))

        if z.imag < 0 || (z.imag == 0 && z.real >= 1)
          s -= 2i * Math::PI * CMath.log(z) ** (n - 1) / (n - 1).factorial
        end

        s
      end

      # Equation 1.5 in Crandall(2006).
      def self.polylog_1_5(n, z, limit)
        (-n).factorial * (-CMath.log(z)) ** (n - 1) -
          limit.downto(0).sum { |k| polylog_bernoulli_number(k - n + 1) / (k.factorial * (k - n + 1)) * CMath.log(z) ** k }
      end

      # Riemann zeta function, used in polylogarithm implementation.
      # This expansion comes from https://mathworld.wolfram.com/RiemannZetaFunction.html
      def self.polylog_zeta(s, limit = 35)
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
      def self.polylog_bernoulli_polynomial(n, x)
        n.downto(0).sum { |k|
          n.choose(k) * polylog_bernoulli_number(n - k) * x ** k
        }
      end

      # Bernoulli numbers for polylogarithm.
      # See https://mathworld.wolfram.com/BernoulliNumber.html
      # See https://en.wikipedia.org/wiki/Bernoulli_number#Explicit_definition
      def self.polylog_bernoulli_number(n)
        @bn ||= []
        @bn[n] ||= n.downto(0).sum { |k|
          1.0 / (k + 1) * k.downto(0).sum { |r|
            (-1) ** r * k.choose(r) * r ** n
          }
        }
      end

      # Harmonic numbers as described in Crandall(2006) for equation 1.4.
      def self.polylog_harmonic(q)
        q.downto(1).sum { |k| 1.0 / k }
      end
    end
  end
end
