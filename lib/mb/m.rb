require 'matrix'

require 'cmath'
require 'numo/narray'

require 'mb-util'

require_relative 'm/version'
require_relative 'm/numeric_extensions'
require_relative 'm/interpolation_methods'
require_relative 'm/precision_methods'
require_relative 'm/coercion_methods'
require_relative 'm/range_methods'
require_relative 'm/array_methods'
require_relative 'm/exponential_methods'
require_relative 'm/special_functions'
require_relative 'm/trig_methods'
require_relative 'm/regression_methods'
require_relative 'm/root_methods'
require_relative 'm/random_methods'
require_relative 'm/matrix_methods'
require_relative 'm/vector_methods'

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
    extend CoercionMethods
    extend RangeMethods
    extend ArrayMethods
    extend ExponentialMethods
    extend SpecialFunctions
    extend TrigMethods
    extend RegressionMethods
    extend RootMethods
    extend RandomMethods

    extend MatrixMethods
    extend VectorMethods

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
require_relative 'm/polynomial'
