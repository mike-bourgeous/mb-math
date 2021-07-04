module MB
  module M
    # Functions relating to powers, exponents, and logarithms.
    module ExponentialMethods
      # The polylogarithm function, useful for computing integrals of
      # logarithms.
      #
      # See https://cs.stackexchange.com/questions/124418/algorithm-to-calculate-polylogarithm/124420#124420
      # See https://www.reed.edu/physics/faculty/crandall/papers/Polylog.pdf
      # See https://en.wikipedia.org/wiki/Spence%27s_function
      def polylog(order, z)
        case order
        when 1
          -CMath.log(1.0 - z)

        when 0
          z / (1.0 - z)

        else

          # TODO
          raise NotImplementedError, 'TODO'
        end
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
    end
  end
end
