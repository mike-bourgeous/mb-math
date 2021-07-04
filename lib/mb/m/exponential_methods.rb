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
            polylog_zeta(order)

          when -1
            -(1.0 - 2.0 ** (1.0 - order)) * polylog_zeta(order)

          else
            limit = (10 * Math.log2(10)).ceil

            if z.abs <= 0.5
              polylog_1_1(order, z, limit)
            elsif z.abs >= 2
              polylog_1_3(order, z, limit) - (-1) ** order * polylog_1_1(order, 1.0 / z, limit)
            elsif order > 0
              polylog_1_4(order, z, limit)
            else
              polylog_1_5(order, z, limit)
            end
          end
        end
      end

      # polylog(2, x)
      def dilog(x)
        @dilog_min ||= x # XXX
        @dilog_max ||= x
        @dilog_min = x if x.real < @dilog_min.real || x.imag < @dilog_max.imag
        @dilog_max = x if x.real > @dilog_max.real || x.imag > @dilog_max.imag
        puts "dilog(\e[1m#{x.inspect}\e[0m) \e[33mmin=\e[1m#{@dilog_min}\e[0m \e[35mmax=\e[1m#{@dilog_max}\e[0m" # XXX

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
      def polylog_1_1(n, z, limit)
        (1..limit).lazy.map { |k| z ** k / k ** n }.sum
      end

      # Equation 1.4 in Crandall(2006).
      def polylog_1_4(n, z, limit)
        (0..limit).lazy.map { |m|
          next 0 if (n - m) == 1 # sigma prime notation from the paper
          polylog_zeta(n - m) / CMath.gamma(m) * CMath.log(z) ** m +
            CMath.log(z) ** (n - 1) / CMath.gamma(n - 1) * (polylog_harmonic(n - 1) - CMath.log(-CMath.log(z)))
        }.sum
      end

      # Right side of equation 1.3 in Crandall(2006).
      def polylog_1_3(n, z, limit)
        s = -(2i * Math::PI) ** n / CMath.gamma(n) * polylog_bernoulli(n, CMath.log(z) / 2i * Math::PI)

        if z.imag < 0 || (z.imag == 0 && z.real >= 1)
          s -= 2i * Math::PI * CMath.log(z) ** (n - 1) / CMath.gamma(n - 1)
        end

        s
      end

      # Equation 1.5 in Crandall(2006).
      def polylog_1_5(n, z, limit)
        raise 'TODO'
      end

      def polylog_zeta(s, limit = 100)
        # FIXME: this does not converge, at least when s < 1 or when s is not real; need a better algorithm
        (1..limit).lazy.map { |n| n.to_f ** -s }.sum
      end

      def polylog_bernoulli(n, z)
        warn 'TODO'
        0
      end

      # Harmonic numbers as described in Crandall(2006) for equation 1.4.
      def polylog_harmonic(q)
        (1..q).lazy.map { |k| 1.0 / k }.sum
      end
    end
  end
end
