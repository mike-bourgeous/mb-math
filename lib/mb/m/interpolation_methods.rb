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
          a * (1 - blend) + b * blend
        end
      end

      def cubic_coeffs_matrix(y1, d1, y2, d2)
        # https://math.stackexchange.com/a/1522453/730912
        xmat = Matrix[
          [0, 0, 0, 1],
          [1, 1, 1, 1],
          [0, 0, 1, 0],
          [3, 2, 1, 0]
        ]
        ymat = Matrix[
          [y1],
          [y2],
          [d1],
          [d2]
        ]
        (xmat.inv * ymat).to_a.flatten
      end

      # Directly computes coefficients for a cubic with the given value and
      # derivative at x=0 (y0 and d0) and x=1 (y1 and d1).
      def cubic_coeffs_direct(y0, d0, y1, d1)
        [
          2 * (y0 - y1) + d0 + d1,
          3 * (y1 - y0) - 2 * d0 - d1,
          d0,
          y0
        ]
      end

      # Fits a cubic polynomial to (0, +y0+), (1, +y1+) with slopes (0, +d0+)
      # and (1, +d1+), then returns the value at x = +blend+.
      #
      # See #cubic_lookup.
      # TODO: support other data types like #interp does?
      def cubic_interp(y0, d0, y1, d1, blend)
        coeff = cubic_coeffs_direct(y0, d0, y1, d1)

        ret = coeff[0] * blend ** 3 + coeff[1] * blend ** 2 + coeff[2] * blend + coeff[3]
        ret
      end

      # Returns an interpolated value from the +array+ at fractional index
      # +idx+ using #cubic_interp.
      #
      # +:mode+ - Behavior for out-of-bound indices: :wrap, :bounce, :zero,
      #           any Numeric, :clamp.
      #
      # TODO: Some kind of unifying design with this, #catmull_rom,
      # #fractional_index, etc.
      def cubic_lookup(array, idx, mode: :wrap)
        ifloor = idx.floor
        ifrac = idx - ifloor

        i1 = ifloor - 1

        case mode
        when :wrap
          v1 = array[(ifloor - 1) % array.length]
          v2 = array[ifloor % array.length]
          v3 = array[(ifloor + 1) % array.length]
          v4 = array[(ifloor + 2) % array.length]

        when :bounce
          v1 = fetch_bounce(array, ifloor - 1)
          v2 = fetch_bounce(array, ifloor)
          v3 = fetch_bounce(array, ifloor + 1)
          v4 = fetch_bounce(array, ifloor + 2)

        when :zero, Numeric
          mode = 0 if mode == :zero
          v1 = fetch_constant(array, ifloor - 1, mode)
          v2 = fetch_constant(array, ifloor, mode)
          v3 = fetch_constant(array, ifloor + 1, mode)
          v4 = fetch_constant(array, ifloor + 2, mode)

        when :clamp
          v1 = fetch_clamp(array, ifloor - 1)
          v2 = fetch_clamp(array, ifloor)
          v3 = fetch_clamp(array, ifloor + 1)
          v4 = fetch_clamp(array, ifloor + 2)

        else
          raise "Invalid array fetch mode: #{mode.inspect}"
        end


        d2 = (v3 - v1) / 2
        d3 = (v4 - v2) / 2

        cubic_interp(
          v2, d2,
          v3, d3,
          ifrac
        )
      end

      # Turns +path+, an Array of keys and indexes from navigating nested
      # Arrays and Hashes, into a String representing the path.
      def path_string(path, prefix: '')
        if path.nil? || path.empty?
          "#{prefix}root"
        else
          "#{prefix}path #{path.map { |p| "[#{p.inspect}]" }.join}"
        end
      end

      # Recursively applies +:operation+ against +scalar+ to each nested value
      # in +data+, traversing through Hashes and Arrays.
      #
      # The +:path+ and +:visited+ parameters are used internally for error
      # detection and reporting.
      #
      # This function preserves cycles in the data structure by replacing the
      # cyclic reference with its modified output value.
      #
      # Examples:
      #     deep_math({a: 1, b: [2, 3]}, :*, 2)
      #     => {a: 2, b: [4, 6]}
      #
      #     deep_math(['a', 'b'], :*, 3)
      #     => ['aaa', 'bbb']
      #
      #     # Cycle
      #     a = [1, 2]
      #     a << a
      #     deep_math(a, :+, 4)
      #     => [5, 6, [...]]
      #
      def deep_math(data, operation, scalar, path: [], visited: {})
        return visited[data] if visited.include?(data)

        case data
        when Hash
          visited[data] = {}
          data.each_with_object(visited[data]) { |(k, v), h|
            h[k] = deep_math(v, operation, scalar, path: path + [k], visited: visited)
          }

        when Array
          visited[data] = Array.new(data.length)
          data.each_with_index.with_object(visited[data]) do |(v, idx), arr|
            arr[idx] = deep_math(v, operation, scalar, path: path + [idx], visited: visited)
          end

        else
          case operation
          when :*
            data * scalar

          when :/
            data / scalar

          when :+
            data + scalar

          when :-
            data - scalar

          when :**
            data ** scalar

          else
            raise ArgumentError, "Unknown operation #{operation.inspect}"
          end
        end

      rescue => e
        raise if e.message.start_with?('Error at')
        raise e.class, "#{path_string(path, prefix: 'Error at ')}: #{e.message}", e.backtrace
      end

      # Recursively applies +:operation+ between the two matching elements in
      # +a+ and +b+, traversing through Hashes and Arrays.  Raises an error if
      # +a+ and +b+ have different schemas, unless +b+ has a Numeric where +a+
      # has a traversable data structure.
      #
      # The +:path+ and +:visited+ parameters are used internally for error
      # detection and reporting.
      def very_deep_math(a, operation, b, path: [], visited: {})
        # TODO: better name
        return visited[a] if visited.include?(a) && visited[a].equal?(visited[b])
        raise 'Cycle detected' if visited.include?(a) || visited.include?(b)

        if a.is_a?(Hash) && b.is_a?(Hash)
          raise 'Hash a and b do not have the same keys' unless a.keys == b.keys

          visited[a] = {}
          visited[b] = visited[a]

          a.each_with_object(visited[a]) { |(k, v), h|
            h[k] = very_deep_math(a[k], operation, b[k], path: path + [k], visited: visited)
          }

        elsif a.is_a?(Array) && b.is_a?(Array)
          raise 'Array a and b do not have the same length' unless a.length == b.length

          visited[a] = Array.new(a.length)
          visited[b] = visited[a]

          a.each_with_index.with_object(visited[a]) { |(v, idx), arr|
            arr[idx] = very_deep_math(a[idx], operation, b[idx], path: path + [idx], visited: visited)
          }

        else
          deep_math(a, operation, b, path: path, visited: visited)
        end

      rescue => e
        raise if e.message.start_with?('Error at')
        raise e.class, "#{path_string(path, prefix: 'Error at ')}: #{e.message}", e.backtrace
      end

      # Computes a nested sum of +values+ weighted by +weights+, each of which
      # must be an Array of the same length.  Each individual element in
      # +values+ may be a complex structure of Hashes and Arrays.  Returns the
      # weighted sum of the values.
      #
      # If the +weights+ add up to 1.0, then this computes the weighted average
      # of the +values+.
      def weighted_sum(values, weights)
        unless values.is_a?(Array) && weights.is_a?(Array) && values.length == weights.length
          raise 'Values and weights must be Arrays of the same length'
        end

        very_deep_math(values, :*, weights).reduce { |a, b| very_deep_math(a, :+, b) }
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

        # The distance between points is used to space control "knots" t0..t3
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

        # The position of t within the control "knots" is used to calculate
        # weighted weights for each of the four input points, blending the
        # result down to a final output.  The actual curve of interest lies
        # between t1 and t2.
        d10 = t1 - t0
        d20 = t2 - t0
        d21 = t2 - t1
        d31 = t3 - t1
        d32 = t3 - t2
        t = blend * d21 + t1
        d0t = t0 - t
        d1t = t1 - t
        d2t = t2 - t
        d3t = t3 - t

        if p0.is_a?(Numo::NArray)
          a1 = p0 * (d1t / d10)
          a1.inplace - (p1 * (d0t / d10))
          a2 = p1 * (d2t / d21)
          a2.inplace - (p2 * (d1t / d21))
          a3 = p2 * (d3t / d32)
          a3.inplace - (p3 * (d2t / d32))

          b1 = (a1.inplace * (d2t / d20)).not_inplace!
          b1.inplace - (a2 * (d0t / d20))
          b2 = (a2.inplace * (d3t / d31)).not_inplace!
          b2.inplace - (a3.inplace * (d1t / d31))

          ((b1.inplace * (d2t / d21)).inplace - (b2.inplace * (d1t / d21))).not_inplace!
        else
          a1 = p0 * (d1t / d10) - p1 * (d0t / d10)
          a2 = p1 * (d2t / d21) - p2 * (d1t / d21)
          a3 = p2 * (d3t / d32) - p3 * (d2t / d32)
          b1 = a1 * (d2t / d20) - a2 * (d0t / d20)
          b2 = a2 * (d3t / d31) - a3 * (d1t / d31)

          b1 * (d2t / d21) - b2 * (d1t / d21)
        end
      end

      private

      # Distance function used by #catmull_rom.
      def cr_distance_squared(p1, p2)
        p1 = [0, p1] if p1.is_a?(Numeric)
        p2 = [1, p2] if p2.is_a?(Numeric)

        case p1.length
        when 2
          (p2[0] - p1[0]).abs ** 2 + (p2[1] - p1[1]).abs ** 2

        when 3
          (p2[0] - p1[0]).abs ** 2 + (p2[1] - p1[1]).abs ** 2 + (p2[2] - p1[2]).abs ** 2

        when 4
          (p2[0] - p1[0]).abs ** 2 + (p2[1] - p1[1]).abs ** 2 + (p2[2] - p1[2]).abs ** 2 + (p2[3] - p1[3]).abs ** 2

        else
          p1.length.times.reduce(0) { |obj, idx|
            obj + (p2[idx] - p1[idx]).abs ** 2
          }
        end
      end
    end
  end
end
