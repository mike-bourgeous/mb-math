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
      # Examples:
      #     deep_math({a: 1, b: [2, 3], 2, operation: :*)
      #     => {a: 2, b: [4, 6]}
      #
      #     deep_math(['a', 'b'], 3, operation: :*)
      #     => ['aaa', 'bbb']
      def deep_math(data, scalar, operation:, path: [], visited: {})
        # TODO: would deep_math(data, operation, scalar) be a better argument layout?
        # XXX require 'pry-byebug' ; binding.pry # XXX
        #raise "Cycle detected with visited #{visited}" if visited.include?(data) # XXX
        raise 'Super deep!' if path.length > 100 # XXX
        return visited[data] if visited.include?(data)

        case data
        when Hash
          visited[data] = {}
          data.map.with_object(visited[data]) { |(k, v), h|
            h[k] = deep_math(v, scalar, operation: operation, path: path + [k], visited: visited)
          }.to_h
          visited[data]

        when Array
          visited[data] = Array.new(data.length)
          data.each_with_index { |v, idx|
            visited[data][idx] = deep_math(v, scalar, operation: operation, path: path + [idx], visited: visited)
          }
          visited[data]

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
        raise e.class, "#{path_string(path, prefix: 'Error at ')}: #{e.message}", e.backtrace_locations
      end

      # Recursively applies +:operation+ between the two matching elements in
      # +a+ and +b+, traversing through Hashes and Arrays.  Raises an error if
      # +a+ and +b+ have different schemas, unless +b+ has a Numeric where +a+
      # has a traversable data structure.
      def very_deep_math(a, b, operation:, path: [], visited: {})
        # TODO: better name
        # TODO: can we handle cycles by ensuring that both a and b are in visited?
        raise 'Cycle detected' if visited.include?(a) || visited.include?(b)

        if a.is_a?(Hash) && b.is_a?(Hash)
          raise 'Hash a and b do not have the same keys' unless a.keys == b.keys

          visited[a] = true
          visited[b] = true

          a.map { |k, v|
            [k, very_deep_math(a[k], b[k], operation: operation, path: path + [k], visited: visited)]
          }.to_h

        elsif a.is_a?(Array) && b.is_a?(Array)
          raise 'Array a and b do not have the same length' unless a.length == b.length

          visited[a] = true
          visited[b] = true

          a.map.with_index { |v, idx|
            very_deep_math(a[idx], b[idx], operation: operation, path: path + [idx], visited: visited)
          }

        else
          deep_math(a, b, operation: operation, path: path, visited: visited)
        end

      rescue => e
        raise if e.message.start_with?('Error at')
        raise e.class, "#{path_string(path, prefix: 'Error at ')}: #{e.message}", e.backtrace_locations
      end

      # Multiplies +value+ recursively by +scalar+, traversing through Hashes
      # and Arrays.
      #
      # Used by #multi_blend for weighted interpolation.
      #
      def deep_multiply(value, scalar)
        deep_math(value, scalar, operation: :*)
      end

      def multi_blend(values, weights, func: nil)
        very_deep_math(values, weights, operation: :*)
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
