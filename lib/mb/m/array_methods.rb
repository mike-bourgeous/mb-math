module MB
  module M
    # Methods for shifting, modifying, etc. Numo::NArray
    module ArrayMethods
      # Converts a Ruby Array of any nesting depth to a Numo::NArray with a
      # matching number of dimensions.  All nested arrays at a particular depth
      # should have the same size (that is, all positions should be filled).
      #
      # Chained subscripts on the Array become comma-separated subscripts on the
      # NArray, so array[1][2] would become narray[1, 2].
      #
      # TODO: Should this go away in favor of Numo::NArray.cast(...)?
      def array_to_narray(array)
        return array if array.is_a?(Numo::NArray)
        narray = Numo::NArray[array]
        narray.reshape(*narray.shape[1..-1])
      end

      # Sets in-place processing to +inplace+ on the given +narray+, then yields
      # the narray to the given block.
      def with_inplace(narray, inplace)
        was_inplace = narray.inplace?
        inplace ? narray.inplace! : narray.not_inplace!
        yield narray
      ensure
        was_inplace ? narray.inplace! : narray.not_inplace!
      end

      # Appends +append+ to +array+, removing elements from the start of
      # +array+ so that its length remains the same.  Modifies +array+ in
      # place.  Returns the data that was shifted out.
      def append_shift(array, append)
        raise "Only 1D arrays supported" if array.ndim != 1 || append.ndim != 1

        return append if append.length == 0

        remainder = array.length - append.length

        case
        when remainder < 0
          raise "Cannot append more than the length of the original array"

        when remainder == 0
          leftover = array[0..-1].copy
          array[0..-1] = append

        else
          leftover = array[0...append.length].copy
          array[0...remainder] = array[-remainder..-1]
          array[remainder..-1] = append
        end

        leftover
      end

      # Returns a new array padded with the given +value+ (or +before+ before and
      # +after+ after) to provide a size of at least +min_length+.  Returns the
      # original array if it is already long enough.  The default value is zero if
      # not specified.
      #
      # Use 0 for +alignment+ to leave the original data at the start of the
      # resulting array, 1 to leave it at the end of the array, and something in
      # between to place it in the middle (e.g. 0.5 for centering the data).
      def pad(narray, min_length, value: nil, before: nil, after: nil, alignment: 0)
        return narray if narray.size >= min_length

        value ||= 0
        before ||= value
        after ||= value

        add = min_length - narray.size
        length_after = (add * (1.0 - alignment)).round
        length_before = add - length_after

        if length_before > 0
          narray_before = narray.class.new(length_before).fill(before)
          if narray.size > 0
            narray = narray_before.append(narray)
          else
            narray = narray_before
          end
        end

        if length_after > 0
          narray_after = narray.class.new(length_after).fill(after)
          if narray.size > 0
            narray = narray.append(narray_after)
          else
            narray = narray_after
          end
        end

        narray
      end

      # Returns a new array padded with zeros to provide a size of at least
      # +min_length+.  Returns the original array if it is already long enough.
      #
      # See #pad for +alignment+.
      def zpad(narray, min_length, alignment: 0)
        pad(narray, min_length, value: 0, alignment: alignment)
      end

      # Returns a new array padded with ones to provide a size of at least
      # +min_length+.  Returns the original array if it is already long enough.
      #
      # See #pad for +alignment+.
      def opad(narray, min_length, alignment: 0)
        pad(narray, min_length, value: 1, alignment: alignment)
      end

      # Rotates a 1D NArray left by +n+ places, which must be less than the
      # length of the NArray.  Returns the array unmodified if +n+ is zero.
      # Use negative values for +n+ to rotate right.
      def rol(array, n)
        return array if n == 0
        a, b = array.split([n])
        b.concatenate(a)
      end

      # Rotates a 1D NArray right by +n+ places (calls .rol(array, -n)).
      def ror(array, n)
        rol(array, -n)
      end

      # Removes the first +n+ entries of 1D +array+ and adds +n+ zeros at the
      # end.  Cannot shift right; use .shr for that.
      def shl(array, n)
        return array if n == 0 || array.size == 0
        return array.class.zeros(array.size) if array.size <= n
        array[n..-1].concatenate(array.class.zeros(n))
      end

      # Removes the last +n+ entries of 1D +array+ and adds +n+ zeros at the
      # start.  Cannot shift left; use .shl for that.
      def shr(array, n)
        return array if n == 0 || array.size == 0
        return array.class.zeros(array.size) if array.size <= n
        array.class.zeros(n).concatenate(array[0..-(n + 1)])
      end

      # Retrieves values from the given +array+ in a zigzag, reflecting off the
      # ends of the array.  The endpoints are returned only once when passing
      # the edge of the array.
      #
      # Example:
      #     MB::M.fetch_bounce([1, 2, 3], 2) # => 3
      #     MB::M.fetch_bounce([1, 2, 3], 3) # => 2
      #     MB::M.fetch_bounce([1, 2, 3], 4) # => 1
      #     MB::M.fetch_bounce([1, 2, 3], 5) # => 2
      def fetch_bounce(array, idx)
        return array[idx] if idx >= 0 && idx < array.length

        idx %= array.length * 2 - 2
        idx = ((array.length - 2) - idx) if idx >= (array.length - 1)
        array[idx]
      end
    end
  end
end
