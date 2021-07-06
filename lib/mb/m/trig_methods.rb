module MB
  module M
    # Methods related to trigonometry.
    module TrigMethods
      # The first antiderivative of the cosecant function, using exponential
      # instead of sine to preserve both real and imaginary components.
      #
      # The imaginary part looks like a square wave.
      #
      # See https://en.wikipedia.org/wiki/Integral_of_the_secant_function#Hyperbolic_forms
      # See https://www.wolframalpha.com/input/?i=INTEGRATE+%282i%2F%28e%5E%28i*z%29-e%5E%28-i*z%29%29%29
      def csc_int(x)
        # Scale and offset adjusted to match plot on Wolfram Alpha
        # FIXME: this does not return the correct imaginary component when given an imaginary argument
        -2.0 * CMath.atanh(CMath.exp(1i * x)).conj + Math::PI / 2i
      end

      # The second antidervative of the cosecant (or at least the
      # antiderivative of #csc_int).
      #
      # The imaginary part looks like a triangle wave within -pi..pi.
      def csc_int_int(x)
        # The derivative (#csc_int) has discontinuities at 0 and pi so we have
        # to fill in these gaps.
        return 2.46740110027234i if x == 0
        return -2.46740110027234i if x == Math::PI || x == -Math::PI

        x * (CMath.log(CMath.exp(1i * x) + 1) - CMath.log(CMath.exp(1i * x) - 1)) -
          2 * x * CMath.atanh(CMath.exp(1i * x)) +
          1i * CMath.log(-CMath.exp(1i * x)) * CMath.log(CMath.exp(1i * x) + 1) +
          x * CMath.log(CMath.exp(1i * x) - 1) +
          1i * dilog(CMath.exp(1i * x) + 1) -
          1i * dilog(-CMath.exp(1i * x) + 1)
      end
    end
  end
end
