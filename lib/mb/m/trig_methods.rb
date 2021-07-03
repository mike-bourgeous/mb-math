module MB
  module M
    # Methods related to trigonometry.
    module TrigMethods
      # The first antiderivative of the cosecant function, using exponential
      # instead of sine to preserve both real and imaginary components.
      #
      # See https://en.wikipedia.org/wiki/Integral_of_the_secant_function#Hyperbolic_forms
      # See https://www.wolframalpha.com/input/?i=INTEGRATE+%282i%2F%28e%5E%28i*z%29-e%5E%28-i*z%29%29%29
      def csc_int(x)
        # Scale and offset adjusted to match plot on Wolfram Alpha
        # FIXME: this does not return the correct imaginary component when given an imaginary argument
        -2.0 * CMath.atanh(CMath.exp(1i * x)).conj + Math::PI / 2i
      end
    end
  end
end
