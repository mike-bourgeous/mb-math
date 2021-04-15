require 'numo/narray'

require_relative 'math/version'
require_relative 'm/interpolation_methods'

module MB
  # Functions for clamping, scaling, interpolating, etc.  Extracted from
  # mb-sound and various other personal projects.
  module M
    extend InterpolationMethods
  end
end
