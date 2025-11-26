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

        # TODO: Add Hash support?

        return value.map { |v| sigfigs(v, figs) } if value.respond_to?(:map)

        # TODO: should this do something different when real and imag have very different magnitudes?
        return Complex(sigfigs(value.real, figs), sigfigs(value.imag, figs)) if value.is_a?(Complex)

        round_digits = figs - Math.log10(value.abs).ceil
        return 0.0 if round_digits > Float::MAX_10_EXP

        value.round(round_digits)
      end

      # Rounds the given Complex, Float, Array, Numeric, or Numo::NArray to the
      # given number of digits after the decimal point, removing the imaginary
      # part of Complex numbers if it goes to zero.  Recursively follows nested
      # Hash and Array data structures to find numeric values to round.
      def round(value, figs = 0)
        if value.is_a?(Numo::NArray)
          exp = (10 ** figs.floor).to_f
          (value * exp).round / exp
        elsif value.is_a?(Complex)
          real, imag = value.real.round(figs), value.imag.round(figs)
          return real if imag == 0
          Complex(real, imag)
        elsif value.is_a?(Hash)
          value.map { |k, v|
            [k, round(v, figs)]
          }.to_h
        elsif value.respond_to?(:map)
          value.map { |v| round(v, figs) }
        else
          value.round(figs)
        end
      end

      # Rounds the given value to the closest multiple of +multiple+ starting
      # from +offset+, or returns the value unmodified if +multiple+ is zero..
      #
      # Examples:
      #     # Round to nearest multiple of 30
      #     round_to(35, 30) # => 30
      #     round_to(50, 30) # => 60
      #
      #     # Round to multiples of 2.5 with an offset of 0.5
      #     round_to(4, 2.5, 0.5) # => 3.0
      #     round_to(4.5, 2.5, 0.5) # => 5.5
      #
      #     # Round multiple values at once
      #     round_to(Numo::SFloat[1, 2, 3, 4, 5], 2, 0.5) # => Numo::SFloat[0.5, 2.5, 2.5, 4.5, 4.5]
      def round_to(value, multiple, offset = 0)
        return value if multiple == 0

        value = value.to_f if value.is_a?(Integer)

        case value
        when Numo::NArray, Numeric
          round(((value - offset) / multiple)) * multiple + offset

        else
          if value.respond_to?(:map)
            value.map { |v| round_to(v, multiple) }
          else
            raise ArgumentError, "Unsupported type for value to round to multiple: #{value.class}"
          end
        end
      end

      # Formats +value+ in with +figs+ significant figures, using SI magnitude
      # prefixes.
      #
      # If +:force_decimal+ is true, then integer values will still print a
      # decimal point.  This is useful for keeping the width of a displayed
      # value nearly constant.  If +:force_decimal+ is false, then no decimal
      # point will be displayed and effectively 3 figures of precision will be
      # used.  If +:force_decimal+ is an IntegerThe default is nil.
      #
      # If +:force_sign+ is true, then a plus sign will be placed in front of
      # non-negative values.
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
      def sigformat(value, figs = 3, force_decimal: nil, force_sign: false)
        if value != 0
          log = Math.log10(value.abs)
          order = log.floor
          kilo_order = (log / 3.0).floor
          extra = (figs - 1) - (order - kilo_order * 3)

          sig = sigfigs(value, figs) / 1000.0 ** kilo_order

          prefix = SI_PREFIXES[kilo_order]
        else
          extra = figs - 1
          sig = value
        end

        sign_prefix = force_sign ? '+' : ''

        extra = 1 if extra < 1 && force_decimal
        extra = force_decimal if force_decimal.is_a?(Integer)

        if force_decimal == nil && (extra <= 0 || sig == sig.round)
          "%#{sign_prefix}.0f#{prefix}" % sig
        elsif force_decimal == false
          "%#{sign_prefix}d#{prefix}" % sig.round
        else
          "%#{sign_prefix}.#{extra}f#{prefix}" % sig
        end
      end
    end
  end
end
