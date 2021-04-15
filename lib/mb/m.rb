require 'numo/narray'

require_relative 'math/version'

module MB
  module M
    # Returns a value between 0 and 1 for inputs between 0 and 1, with the edges
    # smoothed so that velocity starts at 0.
    #
    # See https://commons.wikimedia.org/wiki/File:Smoothstep_and_Smootherstep.svg
    # (I made that graph)
    def self.smoothstep(x)
      3*x*x - 2*x*x*x
    end

    # Returns a value between 0 and 1 for inputs between 0 and 1, with the edges
    # smooth so that both velocity and acceleration start at 0.
    #
    # See https://commons.wikimedia.org/wiki/File:Smoothstep_and_Smootherstep.svg
    def self.smootherstep(x)
      6*x**5 - 15*x**4 + 10*x**3
    end

    # Interpolates between values, hashes, or arrays, +a+ and +b+, extrapolating
    # if blend is outside the range 0..1.  Returns a when blend is 0, b when
    # blend is 1, (a + b) / 2 when blend is 0.5.
    #
    # If +a+ and/or +b+ are Numo:NArrays, they should be set to not-inplace.
    #
    # If +:func+ is not nil, then it will be called with the +blend+ value and
    # its return value used instead.  As an example, this allows other
    # interpolation functions to be used.
    def self.interp(a, b, blend, func: nil)
      if a.is_a?(Hash) && b.is_a?(Hash)
        a.map { |k, v|
          [k, interp(v, b[k], blend, func: func)]
        }.to_h
      elsif a.is_a?(Array) && b.is_a?(Array)
        raise 'Arrays must be the same length' unless a.length == b.length
        a.each_with_index.map { |v, idx|
          interp(v, b[idx], blend, func: func)
        }
      else
        blend = func.call(blend) if func
        (1 - blend) * a + blend * b
      end
    end
  end
end
