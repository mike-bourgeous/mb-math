module MB
  module M
    # Rounding and significant figures.
    module PrecisionMethods
      extend self

      # Rounds +value+ (Float, Complex, Numo::NArray, Array of Float) to
      # roughly +figs+ significant digits.  If +value+ is near the bottom end
      # of the floating point range (around 10**-307), 0 may be returned
      # instead.  If +value+ is an array, the values in the array will be
      # rounded.
      def sigfigs(value, figs)
        raise 'Number of significant digits must be >= 1' if figs < 1
        return 0.0 if value == 0

        return value.map { |v| sigfigs(v, figs) } if value.respond_to?(:map)

        # TODO: should this do something different when real and imag have very different magnitudes?
        return Complex(sigfigs(value.real, figs), sigfigs(value.imag, figs)) if value.is_a?(Complex)

        round_digits = figs - Math.log10(value.abs).ceil
        return 0.0 if round_digits > Float::MAX_10_EXP

        value.round(round_digits)
      end

      # Rounds the given Complex, Float, Array, or Numo::NArray to the given
      # number of digits after the decimal point.
      def round(value, figs = 0)
        if value.is_a?(Numo::NArray)
          exp = (10 ** figs.floor).to_f
          return (value * exp).round / exp
        elsif value.is_a?(Complex)
          return Complex(value.real.round(figs), value.imag.round(figs))
        elsif value.respond_to?(:map)
          return value.map { |v| round(v, figs) }
        else
          return value.round(figs)
        end
      end

    end
  end
end
