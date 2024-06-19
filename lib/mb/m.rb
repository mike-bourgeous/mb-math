require 'matrix'

require 'cmath'
require 'numo/narray'

require 'mb-util'

require_relative 'm/version'
require_relative 'm/interpolation_methods'
require_relative 'm/precision_methods'
require_relative 'm/range_methods'
require_relative 'm/array_methods'
require_relative 'm/exponential_methods'
require_relative 'm/special_functions'
require_relative 'm/trig_methods'
require_relative 'm/regression_methods'

module MB
  # Functions for clamping, scaling, interpolating, etc.  Extracted from
  # mb-sound and various other personal projects.
  #
  # This is called M and not Math to avoid aliasing with the top-level ::Math
  # module.
  module M
    # Catalan's constant, calculated to 53 bits using Sage.  Relevant to polylogarithms.
    Catalan = 0.915965594177219

    extend InterpolationMethods
    extend PrecisionMethods
    extend RangeMethods
    extend ArrayMethods
    extend ExponentialMethods
    extend SpecialFunctions
    extend TrigMethods
    extend RegressionMethods

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
    end

    Numeric.include(NumericMathDSL)

    # Returns an array with the two complex roots of a quadratic equation with
    # the given coefficients.
    def self.quadratic_roots(a, b, c)
      disc = CMath.sqrt(b * b - 4.0 * a * c)
      denom = 2.0 * a
      [
        ((-b + disc) / denom).to_c,
        ((-b - disc) / denom).to_c
      ]
    end

    # Parses +v+ as a Float or Complex.  Supports polar notation using degrees
    # separated by a less-than sign, with or without spaces.
    #
    # Examples:
    #     MB::M.parse_complex('.5')
    #     # => 0.5
    #
    #     MB::M.parse_complex('3-.2i')
    #     # => 3.0-0.2i
    #
    #     MB::M.parse_complex('1 < 90')
    #     # => 0.0+1.0i
    def self.parse_complex(v)
      case v
      when /\s*[+-]?(\.\d+|\d+(\.\d+)?)\s*<\s*[+-]?(\.\d+|\d+(\.\d+)?)\s*/
        # Complex number in polar form with degrees, e.g. 0.5<37
        mag, deg = v.split('<')
        Complex.polar(Float(mag.strip), Float(deg.strip).degrees)

      else
        begin
          Float(v)
        rescue
          begin
            Complex(v)
          rescue
            v = v.gsub(/\s+/, '') if v.is_a?(String)
            Complex(v)
          end
        end
      end
    end
  end
end

require_relative 'm/plot'
