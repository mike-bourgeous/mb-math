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

      # Sets in-place processing to +inplace+ on the given +narray+, then
      # yields the narray to the given block.
      #
      # Yields +narray+ unaltered if it is not a Numo::NArray and +inplace+ is
      # false.
      #
      # Raises an error if +narray+ is not actually a Numo::NArray and
      # +inplace+ is true.
      def with_inplace(narray, inplace)
        if narray.is_a?(Numo::NArray)
          begin
            was_inplace = narray.inplace?
            inplace ? narray.inplace! : narray.not_inplace!
            yield narray
          ensure
            was_inplace ? narray.inplace! : narray.not_inplace!
          end
        elsif inplace
          raise ArgumentError, 'Inplace must be false if a non-Numo::NArray is given to #with_inplace'
        else
          yield narray
        end
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

      # Reads +length+ elements at the given +offset+ from the +source+
      # Numo::NArray, wrapping around at the end of the array.
      #
      # If a +target+ Numo::NArray is given, then the unwrapped data will be
      # copied into +target+.  Otherwise this method returns a new NArray.
      def circular_read(source, offset, length, target: nil)
        if offset < -source.length || offset >= source.length
          raise IndexError, "Offset #{offset} is out of bounds of source length #{source.length}"
        end

        if target && target.length < length
          raise ArgumentError, "Target length #{target.length} is less than read length #{length}"
        end

        if length > source.length
          # TODO: Should this method be capable of wrapping repeatedly?
          raise ArgumentError, "Length to read (#{length}) is greater than the source length #{source.length}"
        end

        offset += source.length if offset < 0

        endpoint = offset + length
        if endpoint <= source.length
          # Simple read
          if target
            target[0...length] = source[offset...endpoint]
            target
          else
            source[offset...endpoint].dup
          end
        else
          # Wrapped read
          target ||= source.class.new(length).allocate
          before = source.length - offset
          after = length - before
          target[0...before] = source[offset..-1]
          target[before...length] = source[0...after]

          target
        end
      end

      # Writes the +source+ Numo::NArray into the +target+ starting at the
      # given +offset+, wrapping around if necessary.  Behavior is undefined if
      # +target+ and +source+ are the same array, or are views into the same
      # array.  Returns the +target+.
      def circular_write(target, source, offset)
        if offset < -target.length || offset >= target.length
          raise IndexError, "Write offset #{offset} is out of bounds of target buffer (#{target.length})"
        end

        if source.length > target.length
          raise ArgumentError, "Target buffer (#{target.length}) is not large enough for source (#{source.length})"
        end

        offset += target.length if offset < 0

        endpoint = offset + source.length
        if endpoint <= target.length
          # Simple copy
          target[offset...endpoint] = source
        else
          # Wrapped copy
          before = target.length - offset
          after = source.length - before
          target[offset..-1] = source[0...before]
          target[0...after] = source[before..-1]
        end

        target
      end

      # If no block is given, returns a new array padded with the given +value+
      # (or +before+ before and +after+ after) to provide a size of at least
      # +min_length+.  Returns the original array if it is already long enough.
      # The default value is zero if not specified.
      #
      # If a block is given, the padded array is yielded to the block, the
      # padding regions are removed from whatever the block returns (must be
      # the same length narray as given to the block), and the result returned.
      #
      # Use 0 for +alignment+ to leave the original data at the start of the
      # resulting array, 1 to leave it at the end of the array, and something in
      # between to place it in the middle (e.g. 0.5 for centering the data).
      def pad(narray, min_length, value: nil, before: nil, after: nil, alignment: 0)
        if narray.size >= min_length
          if block_given?
            result = yield narray
            if result.shape != narray.shape
              raise "Block result shape #{result.shape} does not match provided shape #{narray.shape}"
            end

            return result
          end

          return narray
        end

        value ||= 0
        before ||= value
        after ||= value

        add = min_length - narray.size
        length_after = (add * (1.0 - alignment)).round
        length_before = add - length_after

        if length_before > 0
          narray_before = narray.class.new(length_before).fill(before)
          if narray.size > 0
            narray = array_append(narray_before, narray)
          else
            narray = narray_before
          end
        end

        if length_after > 0
          narray_after = narray.class.new(length_after).fill(after)
          if narray.size > 0
            narray = array_append(narray, narray_after)
          else
            narray = narray_after
          end
        end

        if block_given?
          result = yield narray
          if result.shape != narray.shape
            raise "Block result shape #{result.shape} does not match provided shape #{narray.shape}"
          end
          result[length_before..-(length_after + 1)]
        else
          narray
        end
      end

      # Returns a new array padded with zeros to provide a size of at least
      # +min_length+.  Returns the original array if it is already long enough.
      #
      # See #pad for +alignment+ and block behavior.
      def zpad(narray, min_length, alignment: 0, &bl)
        pad(narray, min_length, value: 0, alignment: alignment, &bl)
      end

      # Returns a new array padded with ones to provide a size of at least
      # +min_length+.  Returns the original array if it is already long enough.
      #
      # See #pad for +alignment+ and block behavior.
      def opad(narray, min_length, alignment: 0, &bl)
        pad(narray, min_length, value: 1, alignment: alignment, &bl)
      end

      # Returns a new Array or a Numo::NArray view with leading copies of
      # +value+ removed from the given +array+.  Returns an empty array if the
      # array is entirely equal to +value+.
      #
      # For Ruby Arrays, this just calls Array#drop_while.  The method is
      # provided mainly for use with Numo::NArray.
      #
      # Example:
      #     MB::M.ltrim([0, 1, 2, 3])
      #     # => [1, 2, 3]
      #
      #     MB::M.ltrim(Numo::SFloat[1, 1, 2, 3, 4], 1)
      #     # => [2, 3, 4]
      #
      # If a block is given, then each leading value will be yielded to the
      # block, and the leading elements for which the block returns true will
      # be removed (iteration will stop when the block returns false).  The
      # +value+ parameter is ignored when a block is given.
      #
      # Example:
      #     MB::M.ltrim([1, 3, 5, 2, 4, 6], &:odd?)
      #     # => [2, 4, 6]
      #
      # Comparison uses the == and != operators, so 0.0 and -0.0 are considered
      # equal.
      def ltrim(array, value = 0)
        case array
        when Numo::NArray
          # TODO: there's got to be a faster way to do this, like a
          # clz/count-leading-zeros function or something
          # TODO: add an approximation option and use nearly_eq?

          if block_given?
            idx = array.each_with_index { |v, idx| break idx if !yield(v) }
          else
            idx = array.each_with_index { |v, idx| break idx if v != value }
          end
          idx = nil unless idx.is_a?(Integer) # if we didn't break then we got the array instead

          return array.class[] if idx.nil?

          array[idx..]

        when Array
          if block_given?
            array.drop_while { |v| yield v }
          else
            array.drop_while { |v| v == value }
          end

        else
          raise ArgumentError, "Expecting Numo::NArray or Array, got #{array.class}"
        end
      end
      alias skip_leading ltrim

      # Returns a new Array or a Numo::NArray view with trailing copies of
      # +value+ removed from the +array+.  Returns an empty array if the array
      # is entirely equal to +value+.
      #
      # If a block is given, then instead of using +value+, array elements are
      # removed from the end as long as the block returns true when yielded the
      # element.  Returns an empty array if the block always returns true.
      def rtrim(array, value = 0)
        case array
        when Numo::NArray, Array
          idx = nil

          if block_given?
            for i in (-1..-array.length).step(-1)
              unless yield array[i]
                idx = i
                break
              end
            end
          else
            for i in (-1..-array.length).step(-1)
              unless array[i] == value
                idx = i
                break
              end
            end
          end

          return array.class[] if idx.nil?

          array[0..idx]

        else
          raise ArgumentError, "Expecting Numo::NArray or Array, got #{array.class}"
        end
      end
      alias skip_trailing rtrim

      # Equivalent to both rtrim and ltrim together.  Calls ltrim first, then
      # rtrim.
      def trim(array, value = 0)
        if block_given?
          a = ltrim(array) do |v| yield v end
          rtrim(a) do |v| yield v end
        else
          rtrim(ltrim(array, value), value)
        end
      end

      # Rotates a 1D NArray left by +n+ places, which must be less than the
      # length of the NArray.  Returns a duplicate of the original array if +n+
      # is zero or the rotation would have no effect.  Use negative values for
      # +n+ to rotate right.
      def rol(array, n)
        # TODO: Support in-place modification
        return array.dup if array.length <= 1

        n %= array.length
        return array.dup if n == 0

        if array.is_a?(Array)
          a = array[0...n]
          b = array[n..-1]
          b + a
        else
          a, b = array.split([n])
          b.concatenate(a)
        end
      end

      # Rotates a 1D NArray right by +n+ places (calls .rol(array, -n)).
      def ror(array, n)
        # TODO: Support in-place modification
        rol(array, -n)
      end

      # Removes the first +n+ entries of 1D +array+ and adds +n+ zeros at the
      # end.  Cannot shift right; use .shr for that.
      def shl(array, n)
        # TODO: Support in-place modification
        return array if n == 0 || array.size == 0
        return array.class.zeros(array.size) if array.size <= n
        array[n..-1].concatenate(array.class.zeros(n))
      end

      # Removes the last +n+ entries of 1D +array+ and adds +n+ zeros at the
      # start.  Cannot shift left; use .shl for that.
      def shr(array, n)
        # TODO: Support in-place modification
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

      # Repeatedly copies +:source+ into +:destination+, starting at the given
      # +:source_offset+.  Wraps around +:source+ at the end, but does not wrap
      # around +:destination+.  Both +:source+ and +:destination+ should be
      # Numo::NArrays.
      #
      # Returns the new source offset to use to continue the repeating pattern.
      def repeat(source:, destination:, source_offset: 0)
        srclen = source.length
        dstlen = destination.length

        if source_offset < 0 || source_offset >= source.length
          raise IndexError, "Source offset #{source_offset} is out of range of source length #{source.length}"
        end

        prefix_length = srclen - source_offset

        raise NotImplementedError
        # TODO: Prefix from source_offset to source_length or destination end
        # TODO: Main loop copying all of source in srclen chunks
        # TODO: Suffix from source 0 until end of destination
      end

      # Interpolates between values neighboring +index+ in the given +array+,
      # optionally using a given interpolation function.  See
      # InterpolationMethods#interp.
      def fractional_index(array, index, func: nil)
        i1 = index.floor
        i2 = index.ceil
        blend = index - i1
        MB::M.interp(array[i1], array[i2], blend, func: func)
      end

      # Performs direct convolution of +array1+ with +array2+, returning a new
      # Numo::NArray with the result.  Uses a naive O(n*m) algorithm which is
      # faster than FFT-based convolution when array sizes are around 5-10
      # elements, but otherwise much slower.
      #
      # You should use #fftconvolve in most cases, unless exact results are
      # needed.
      def convolve(array1, array2)
        array1, array2 = array2, array1 if array2.length > array1.length

        length = array1.length + array2.length - 1

        if length > 100
          @@warned_about_convolution ||= false
          unless @@warned_about_convolution
            warn 'SPEED WARNING: Use fftconvolve for faster convolution'
            @@warned_about_convolution = true
          end
        end

        result = promoted_array_type(array1, array2).zeros(length)

        for i in 0...array1.length
          for j in 0...array2.length
            result[i + j] += array2[j] * array1[i]
          end
        end

        result
      end

      # Uses FFT multiplication to perform fast convolution of +array1+ with
      # +array2+, which may be 1D Ruby Arrays or Numo::NArrays.
      #
      # If both +array1+ and +array2+ are Numo::NArrays, you should call
      # Numo::Pocketfft.fftconvolve instead.
      def fftconvolve(array1, array2)
        type = promoted_array_type(array1, array2)
        length = array1.length + array2.length - 1
        a1 = zpad(type.cast(array1), length)
        a2 = zpad(type.cast(array2), length)
        f1 = Numo::Pocketfft.fft(a1)
        f2 = Numo::Pocketfft.fft(a2)
        d = f1 * f2
        result = Numo::Pocketfft.ifft(d)
        result = result.real unless a1.is_a?(Numo::SComplex) || a1.is_a?(Numo::DComplex) || a2.is_a?(Numo::SComplex) || a2.is_a?(Numo::DComplex)
      end

      # Returns the index of the first element equal to +value+ in the given
      # +array+ (a function that is apparently not built in to Numo::NArray).
      #
      # If a block is given, then the +value+ is ignored, and the block will be
      # yielded each element and its index.  The method will return the first
      # index for which the block returns true.
      #
      # Returns nil if no matching element was found.
      def find_first(array, value = nil)

        if block_given?
          array.each_with_index do |v, idx|
            return idx if yield v, idx
          end
        else
          return array.find_index(value) if array.respond_to?(:find_index)

          array.each_with_index do |v, idx|
            return idx if v == value
          end
        end

        nil
      end

      # Returns the index of the first element that is not equal to +value+ in
      # the given +array+.  Useful for skipping leading zeros, for example.
      #
      # If a block is given, then the +value+ is ignored, and the block will be
      # yielded each element and its index.  The method will return the first
      # index for which the block returns false.
      #
      # Returns nil if no matching element was found.
      def find_first_not(array, value = nil)
        if block_given?
          array.each_with_index do |v, idx|
            return idx unless yield v, idx
          end
        else
          array.each_with_index do |v, idx|
            return idx if v != value
          end
        end

        nil
      end

      # This function finds zero-crossings / sign changes in an Array or
      # Numo::NArray.
      #
      # If +rising+ is true, returns the index of the first non-negative value
      # in the +array+ after at least one negative value.
      #
      # If +rising+ is false, returns the index of the first non-positive value
      # in the +array+ after at least one positive value.
      #
      # Returns nil if the +array+ is empty or if there is never a
      # negative-to-non-negative transition.
      def find_sign_change(array, rising = true)
        return nil if array.empty?

        # TODO: add a threshold parameter that defaults to 0?  Callers can just
        # subtract that threshold before passing the array to this method until
        # then

        prior = array[0]
        if rising
          find_first(array) do |v, _idx|
            (prior < 0 && v >= 0).tap { prior = v }
          end
        else
          find_first(array) do |v, _idx|
            (prior > 0 && v <= 0).tap { prior = v }
          end
        end
      end
      alias find_zero_crossing find_sign_change

      # Uses #find_sign_change to return a subset of +array+ that starts at a
      # sign change and continues until +count+ additional sign changes have
      # been found.  The value that triggered the final sign change is omitted.
      #
      # If +count+ is nil, then all remaining full cycles in the +array+ will
      # be returned.
      #
      # Returns nil if there are fewer than +count+ sign changes after the
      # first sign change or if the +array+ is empty.
      #
      # This can be useful for selecting +count+ cycles of a simple waveform
      # when you don't know the phase or frequency in advance.
      def select_sign_changes(array, count, rising = true)
        if count && !(count.is_a?(Integer) && count >= 1)
          raise ArgumentError, "Count must be falsey or an Integer >= 1"
        end

        return nil if array.empty?

        start_index = find_sign_change(array, rising)
        return nil if start_index.nil?

        end_index = start_index
        if count
          count.times do
            next_index = find_sign_change(array[end_index..], rising)
            return nil unless next_index
            end_index += next_index
          end
        else
          loop do
            next_index = find_sign_change(array[end_index..], rising)
            break unless next_index
            end_index += next_index
          end
        end

        array[start_index...end_index]
      end
      alias select_zero_crossings select_sign_changes

      private

      # For #pad, do the right thing for Numo::NArray and Array to concatenate
      # arrays to a new array.
      def array_append(array1, array2)
        case array1
        when Numo::NArray
          array1.append(array2)

        when Array
          array1 + array2
        end
      end

      PROMOTED_NARRAY_TYPE_MAP = {
        [false, false] => Numo::SFloat,
        [false, true] => Numo::SComplex,
        [true, false] => Numo::DFloat,
        [true, true] => Numo::DComplex,
      }.freeze

      # Returns the Numo::NArray class that should hold (most) of the range of
      # both +array1+ and +array2+.
      def promoted_array_type(array1, array2)
        double = array1.is_a?(Numo::DFloat) || array1.is_a?(Numo::DComplex) ||
          array1.is_a?(Numo::Int32) || array1.is_a?(Numo::Int64) ||
          array2.is_a?(Numo::DFloat) || array2.is_a?(Numo::DComplex) ||
          array2.is_a?(Numo::Int32) || array2.is_a?(Numo::Int64) ||
          array1.is_a?(Array) || array2.is_a?(Array)

        complex = array1.is_a?(Numo::SComplex) || array1.is_a?(Numo::DComplex) ||
          array2.is_a?(Numo::SComplex) || array2.is_a?(Numo::DComplex) ||
          (array1.is_a?(Array) && array1.any?(Complex)) ||
          (array2.is_a?(Array) && array2.any?(Complex))

        PROMOTED_NARRAY_TYPE_MAP[[double, complex]]
      end
    end
  end
end
