module MB
  module M
    # Functions relating to powers, exponents, and logarithms.
    module ExponentialMethods
      # Raises the given +value+ to the given +power+, but using the absolute
      # value function to prevent complex results.  Useful for waveshaping.
      def safe_power(value, power)
        if !value.is_a?(Numeric) && value.respond_to?(:map)
          return value.map { |v| safe_power(v, power) }
        end

        sign = value.positive? ? 1.0 : -1.0
        value.abs ** power * sign
      end
    end
  end
end
