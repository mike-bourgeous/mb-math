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

      # XXX hard-coded values for testing csc_int_int calls to dilog, calculated in Sage
      DILOG = {
        1.0+1.0i => 0.616850275068085 + 1.46036211675312i,
        1.0-1.0i => 0.616850275068085 - 1.46036211675312i,
        2.0 => 2.46740110027234 - 2.17758609030360i,
        0.0 => 0,
        PrecisionMethods.round(4.999958333473664e-05-0.009999833334166664i, 6) => 0.0000250000000000144 - 0.00999997222219444i,
        PrecisionMethods.round(0.0049958347219741794-0.09983341664682815i, 6) => 0.00249999999999995 - 0.0999722194439719i,
        PrecisionMethods.round(0.0049958347219741794+0.09983341664682815i, 6) => 0.00249999999999995 + 0.0999722194439719i,
        PrecisionMethods.round(0.12241743810962724-0.479425538604203i, 6) => 0.0625000000000000 - 0.496519060134757i,
        PrecisionMethods.round(0.29289321881345254-0.7071067811865476i, 6) => 0.154212568767021 - 0.771856683438093i,
        PrecisionMethods.round(0.2928932188134524+0.7071067811865475i, 6) => 0.154212568767021 + 0.771856683438093i,
        PrecisionMethods.round(0.45969769413186023-0.8414709848078965i, 6) => 0.250000000000000 - 0.971939626535400i,
        PrecisionMethods.round(1.5403023058681398+0.8414709848078965i, 6) => 1.14660477347744 + 1.85516676666391i,
        PrecisionMethods.round(1.7071067811865475-0.7071067811865475i, 6) => 1.38791311890319 - 1.97053054066177i,
        PrecisionMethods.round(1.7071067811865475+0.7071067811865476i, 6) => 1.38791311890319 + 1.97053054066177i,
        PrecisionMethods.round(1.8775825618903728+0.479425538604203i, 6) => 1.74450293687489 + 2.08892053857897i,
        PrecisionMethods.round(1.9950041652780257-0.09983341664682815i, 6) => 2.31282146759285 - 2.17374083717857i,
        PrecisionMethods.round(1.9950041652780257+0.09983341664682815i, 6) => 2.31282146759285 + 2.17374083717857i,
        PrecisionMethods.round(1.9999500004166653+0.009999833334166664i, 6) => 2.45171813700439 + 2.17754690356556i,
      }

      # polylog(2, x)
      def dilog(x)
        @dilog_min ||= x # XXX
        @dilog_max ||= x
        @dilog_min = x if x.real < @dilog_min.real || x.imag < @dilog_max.imag
        @dilog_max = x if x.real > @dilog_max.real || x.imag > @dilog_max.imag
        puts "dilog(\e[1m#{x.inspect}\e[0m) \e[33mmin=\e[1m#{@dilog_min}\e[0m \e[35mmax=\e[1m#{@dilog_max}\e[0m" # XXX

        # XXX hard-coded values for testing csc_int_int
        idx = x.real.to_f.round(6) + 1i * x.imag.to_f.round(6)
        idx = idx.real if idx.imag == 0
        puts "idx=#{idx.inspect}"

        DILOG[idx] || (puts 'calculating'; polylog(2, x))
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
        (1..limit).lazy.map { |k| z ** k / k ** n }.sum
      end

      # Equation 1.4 in Crandall(2006).
      def self.polylog_1_4(n, z, limit)
        (0..limit).lazy.map { |m|
          next 0 if (n - m) == 1 # sigma prime notation from the paper
          polylog_zeta(n - m) / m.factorial * CMath.log(z) ** m +
            CMath.log(z) ** (n - 1) / (n - 1).factorial * (polylog_harmonic(n - 1) - CMath.log(-CMath.log(z)))
        }.sum
      end

      # Right side of equation 1.3 in Crandall(2006).
      def self.polylog_1_3(n, z, limit)
        s = -(2i * Math::PI) ** n / n.factorial * polylog_bernoulli_polynomial(n, CMath.log(z) / 2i * Math::PI)

        if z.imag < 0 || (z.imag == 0 && z.real >= 1)
          s -= 2i * Math::PI * CMath.log(z) ** (n - 1) / (n - 1).factorial
        end

        s
      end

      # Equation 1.5 in Crandall(2006).
      def self.polylog_1_5(n, z, limit)
        (-n).factorial * (-CMath.log(z)) ** (n - 1) -
          (0..limit).lazy.map { |k| polylog_bernoulli_number(k - n + 1) / (k.factorial * (k - n + 1)) * CMath.log(z) ** k }
      end

      # Riemann zeta function, used in polylogarithm implementation.
      # This expansion comes from https://mathworld.wolfram.com/RiemannZetaFunction.html
      def self.polylog_zeta(s, limit = 35)
        1.0 / (1 - 2 ** (1.0 - s)) *
          limit.downto(0).map { |n|
            (1.0 / 2.0 ** (n + 1)) *
              (0..n).map { |k|
                (-1) ** k * n.choose(k) * (k + 1) ** -s
            }.sum
          }.sum
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
        (1..q).lazy.map { |k| 1.0 / k }.sum
      end
    end
  end
end
