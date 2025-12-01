module MB
  module M
    # Methods for converting between and clamping to ranges.
    module RangeMethods
      # Scales a numeric value or NArray from from_range to to_range.  Converts
      # values to floats.
      #
      # Example:
      #   scale(5, 0..10, 0..1) # => 0.5
      #   scale(Numo::SFloat[5, 10], 0..10, 0..1) # => Numo::SFloat[0.5, 1.0]
      def scale(value, from_range, to_range)
        if value.is_a?(Numo::NArray)
          if value.length != 0 && !value[0].is_a?(Float) && !value[0].is_a?(Complex)
            value = value.cast_to(Numo::SFloat)
          end
        elsif !value.is_a?(Float) && !value.is_a?(Complex) && value.respond_to?(:to_f) && !value.nil?
          value = value.to_f
        end

        in_min, in_max = from_range.begin, from_range.end
        out_min, out_max = to_range.begin, to_range.end

        # Degenerate ranges should always return the output beginning
        if in_min == in_max || out_min == out_max
          case value
          when Numo::NArray
            return value.inplace? ? value.fill(out_min) : Numo::SFloat.ones(value.length).fill(out_min)

          else
            return out_min.to_f
          end
        end

        ratio = (out_max.to_f - out_min.to_f) / (in_max.to_f - in_min.to_f)

        (value - in_min) * ratio + out_min
      end

      # Clamps the +value+ (or all values within an NArray) to be between +min+ and
      # +max+ (passing through NaN).  Ignores nil limits, so this can also be used
      # as min() or max() by passing nil for the unwanted limit (or pass nil for
      # both to do nothing).
      #
      # Note that for scalar values the types for +min+ and +max+ are preserved, so
      # pass the same type as +value+ if that matters to you.
      def clamp(value, min, max)
        if value.is_a?(Numo::NArray)
          return with_inplace(value, false) { |vnotinp|
            if vnotinp.length > 0 && vnotinp[0].is_a?(Integer) && (min || max)
              # Ensure that an int array clipped to float returns float
              vnotinp = vnotinp.cast_to(Numo::NArray[*[min, max].compact].class)
            end

            vnotinp.clip(min, max)
          }
        end

        value = value < min ? min : value if min
        value = value > max ? max : value if max
        value
      end

      # Returns whichever value is lesser.  If they are the same, returns a.
      def min(a, b)
        a <= b ? a : b
      end

      # Returns whichever value is greater.  If they are the same, returns a.
      def max(a, b)
        a >= b ? a : b
      end

      # Returns whichever value has the greatest absolute value.  If they are the
      # same, returns a.
      def max_abs(a, b)
        a.abs >= b.abs ? a : b
      end
    end
  end
end
