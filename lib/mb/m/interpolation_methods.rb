module MB
  module M
    module InterpolationMethods
      # Returns a value between 0 and 1 for inputs between 0 and 1, with the edges
      # smoothed so that velocity starts at 0.
      #
      # See https://commons.wikimedia.org/wiki/File:Smoothstep_and_Smootherstep.svg
      # (I made that graph)
      def smoothstep(x)
        3*x*x - 2*x*x*x
      end

      # Returns a value between 0 and 1 for inputs between 0 and 1, with the edges
      # smooth so that both velocity and acceleration start at 0.
      #
      # See https://commons.wikimedia.org/wiki/File:Smoothstep_and_Smootherstep.svg
      def smootherstep(x)
        6*x**5 - 15*x**4 + 10*x**3
      end

      # Interpolates between values, hashes, or arrays, +a+ and +b+, extrapolating
      # if blend is outside the range 0..1.  Returns a when blend is 0, b when
      # blend is 1, (a + b) / 2 when blend is 0.5 (unless a custom +:func+ is
      # given).
      #
      # If +a+ and/or +b+ are Numo:NArrays, they should be set to not-inplace.
      #
      # If +:func+ is not nil, then it will be called with the +blend+ value and
      # its return value used instead.  As an example, this allows other
      # interpolation functions to be used.  Extrapolation beyond 0..1 only
      # works if the custom function gives useful results outside 0..1.
      #
      # See spec/lib/mb/m/interpolation_methods_spec.rb for a mostly complete
      # list of everything this function can do.
      def interp(a, b, blend, func: nil)
        if blend.respond_to?(:map)
          return blend.map { |bl|
            interp(a, b, bl, func: func)
          }
        end

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

      # Returns the value at +blend+ (from 0 to 1) of a Catmull-Rom spline
      # between +p1+ and +p2+, using +p0+ and +p3+ as guiding endpoints.  The
      # +alpha+ parameter blends between uniform (0.0), centripetal (0.5,
      # default), and chordal (1.0) Catmull-Rom splines.
      #
      # p0, p1, p2, and p3 may be Numeric values, Arrays, Vectors, or
      # Numo::NArrays.
      #
      # See https://en.wikipedia.org/wiki/Centripetal_Catmull%E2%80%93Rom_spline
      def catmull_rom(p0, p1, p2, p3, blend, alpha = 0.5)
        if p0.is_a?(Array)
          p0 = Numo::NArray.cast(p0)
          p1 = Numo::NArray.cast(p1)
          p2 = Numo::NArray.cast(p2)
          p3 = Numo::NArray.cast(p3)
        end

        # The distance between points is is used to space control "knots" t0..t3
        if alpha != 0
          a = 0.5 * alpha # bake square root into alpha
          t0 = 0.0
          t1 = cr_distance_squared(p1, p0) ** alpha + t0
          t2 = cr_distance_squared(p2, p1) ** alpha + t1
          t3 = cr_distance_squared(p3, p2) ** alpha + t2
        else
          t0 = 0.0
          t1 = 1.0
          t2 = 2.0
          t3 = 3.0
        end

        # The actual curve of interest lies between t1 and t2
        t = MB::M.scale(blend, 0..1, t1..t2)

        # The position of t within the control "knots" is used to calculate
        # weighted weights for each of the four input points, blending the
        # result down to a final output.
        a1 = (t1 - t) / (t1 - t0) * p0 + (t - t0) / (t1 - t0) * p1
        a2 = (t2 - t) / (t2 - t1) * p1 + (t - t1) / (t2 - t1) * p2
        a3 = (t3 - t) / (t3 - t2) * p2 + (t - t2) / (t3 - t2) * p3
        b1 = (t2 - t) / (t2 - t0) * a1 + (t - t0) / (t2 - t0) * a2
        b2 = (t3 - t) / (t3 - t1) * a2 + (t - t1) / (t3 - t1) * a3

        (t2 - t) / (t2 - t1) * b1 + (t - t1) / (t2 - t1) * b2
      end

      private

      # Distance function used by #catmull_rom.
      def cr_distance_squared(p1, p2)
        p1 = [0, p1] if p1.is_a?(Numeric)
        p2 = [1, p2] if p2.is_a?(Numeric)
        # TODO: this could be made faster without transposing
        [p2.to_a, p1.to_a].transpose.map { |v| (v[1] - v[0]).abs ** 2 }.sum
      end
    end
  end
end
