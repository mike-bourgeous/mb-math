module MB
  module M
    # Rounding and significant figures.
    module PrecisionMethods
      extend self

      # Magnitude prefixes (numeric suffixes) from SI.  See #sigformat.
      SI_PREFIXES = {
        -8 => 'y',
        -7 => 'z',
        -6 => 'a',
        -5 => 'f',
        -4 => 'p',
        -3 => 'n',
        -2 => "\u00b5",
        -1 => 'm',
        0 => '',
        1 => 'k',
        2 => 'M',
        3 => 'G',
        4 => 'T',
        5 => 'P',
        6 => 'E',
        7 => 'Z',
        8 => 'Y',
      }

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

      # Formats +value+ in with +figs+ significant figures, using SI magnitude
      # prefixes.
      #
      # Examples (see specs for more examples):
      #     sigformat(0) # => '0'
      #     sigformat(123) # => '123'
      #     sigformat(1234) # => '1.23k'
      #     sigformat(12345) # => '12.3k'
      #     sigformat(12345, 4) # => '12.35k'
      #     sigformat(1234567) # => '1.23M'
      #     sigformat(0.12345) # => '123m'
      #     sgiformat(123, 1) # => '100'
      #     sigformat(0.0001234) # => "123\u00b5"
      def sigformat(value, figs = 3)
        return '0' if value == 0

        log = Math.log10(value.abs)
        order = log.floor
        kilo_order = (log / 3.0).floor
        extra = (figs - 1) - (order - kilo_order * 3)

        sig = sigfigs(value, figs) / 1000.0 ** kilo_order

        prefix = SI_PREFIXES[kilo_order]

        if extra <= 0 || sig == sig.round
          "%d#{prefix}" % sig
        else
          "%.#{extra}f#{prefix}" % sig
        end
      end
    end
  end
end
