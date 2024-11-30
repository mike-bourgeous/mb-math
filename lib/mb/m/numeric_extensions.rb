module MB
  module M
    # Collection of extensions for Numeric and its subclasses.
    module NumericExtensions
      # Methods for more easily working with mathematical concepts directly
      # using Ruby Numerics.
      # TODO: move into separate categorized files
      module NumericMathDSL
        # Returns the number itself (radians are the default).
        def radians
          self
        end
        alias radian radians

        # Converts degrees to radians.
        def degrees
          self * Math::PI / 180.0
        end
        alias degree degrees

        # Converts radians to degrees.
        def to_degrees
          self * 180.0 / Math::PI
        end

        # Formats a number in complex polar form using degrees, using '∠'
        # (\u2220) to separate the magnitude from angle, and '°' (\u00b0) to
        # denote degrees.  The +digits+ parameter controls rounding before
        # display.
        def to_polar_s(digits = 4)
          "#{MB::M.sigfigs(self.abs.to_f, digits).to_f}\u2220#{MB::M.sigfigs(self.arg.to_f.to_degrees, digits).to_f}\u00b0"
        end

        # Returns a non-augmented rotation matrix of the current numeric in radians.
        #
        # Example:
        # 1.degree.rotation
        # => Matrix[....]
        #
        # 90.degree.rotation * Vector[1, 0]
        # => Vector[0, 1]
        def rotation
          # Values are rounded to 12 decimal places so that exact values like 0,
          # 0.5, and 1 come out whole.
          a = self.to_f
          Matrix[
            [Math.cos(a).round(12), -Math.sin(a).round(12)],
            [Math.sin(a).round(12), Math.cos(a).round(12)]
          ]
        end

        # Computes the factorial function for positive integers, computes the
        # gamma(n + 1) function for any other type of number.
        def factorial
          if self.is_a?(Integer) && self >= 0
            if self <= 22
              CMath.gamma(self + 1).to_i
            else
              self.to_i.downto(2).reduce(1, :*)
            end
          else
            CMath.gamma(self + 1)
          end
        end

        # Computes the binomial coefficient, or self choose other.
        def choose(other)
          return 0 if other < 0 || other > self
          self.factorial / (other.factorial * (self - other).factorial)
        end

        # Converts to a Float if a 1D Numeric, or converts to a Complex with
        # Floats if a Complex.
        def to_f_or_cf
          if self.is_a?(Complex)
            Complex(real.to_f, imag.to_f)
          else
            self.to_f
          end
        end

        # For Complex numbers, returns the magnitude while trying to preserve
        # Integer and Rational values.  For non-Complex numbers, #abs_r is the
        # same as #abs.
        def abs_r
          if self.is_a?(Complex)
            MB::M.kind_sqrt(real * real + imag * imag)
          else
            abs
          end
        end
      end

      Numeric.include(NumericMathDSL)
    end
  end
end
