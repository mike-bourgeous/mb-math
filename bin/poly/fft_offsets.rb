#!/usr/bin/env ruby
# Experiment to understand array offsets after FFT-based deconvolution.
# (C)2024 Mike Bourgeous
#
# I've implemented a polynomial long division algorithm so don't really need
# the FFT version anymore, but I still want to understand why I haven't been
# able to predict the offset of the result.
#
# Background: the coefficients of the quotient polynomial end up padded in a
# longer array, and the offset of the values to keep within that array is
# currently unpredictable.
#
# Some guesses: I do some padding and offsetting to try to reduce FFT-induced
# error and avoid any near-zeros in the FFT (which would explode under
# division).  There may also be a difference in offset behavior between even
# and odd lengths.
#
# This script will generate a bunch of polynomials of varying lengths, multiply
# them together, then divide one of the multiplicands back out of the product,
# expecting the other multiplicand as result.  It will then find the correct
# offset and print a table of offsets to help me look for a pattern.
#
# The FFT division code is working correctly if the a_calc and b_calc columns
# are always zero, never nil or some other value.
#
# Examples taken from my command history:
#     SEED=0 ORDER_A=3 ORDER_B=6 MIN_OFFSET=-10 MAX_OFFSET=10 bin/fft_offsets.rb
#     SEED=0 ORDER_A=3 ORDER_B=6 REPEATS=6 MIN_OFFSET=-3 MAX_OFFSET=3 bin/fft_offsets.rb
#     SEED=0 ORDER_A=6 ORDER_B=6 REPEATS=6 MIN_OFFSET=-18 MAX_OFFSET=18 OFFSET_C=0 bin/fft_offsets.rb
#     SEED=0 ORDER_A=6 ORDER_B=6 REPEATS=6 MIN_OFFSET=-18 MAX_OFFSET=18 OFFSET_C=3 bin/fft_offsets.rb
#     SEED=0 REPEATS=30 bin/fft_offsets.rb
#     COEFF_A='[-33, -97, -65]' COEFF_B='[89, 0, -89, 0]' PRINT_JSON=1 SEED=0 MIN_PAD=1 MAX_PAD=10 bin/fft_offsets.rb
#     COEFF_A='[-33, -97, -65]' PRINT_JSON=1 SEED=0 bin/fft_offsets.rb
#     COEFF_B='[5, 0, -5, 0]' COEFF_A='[89, 0, 89, 0]' REPEATS=1 PRINT_JSON=1 MIN_OFFSET=0 MAX_OFFSET=0 MIN_PAD=10 MAX_PAD=25 bin/fft_offsets.rb

require 'bundler/setup'

require 'json'
require 'mb/util'

require 'mb/math'

COEFF_A=ENV['COEFF_A']&.yield_self { |v| JSON.parse(v) }
COEFF_B=ENV['COEFF_B']&.yield_self { |v| JSON.parse(v) }

ORDER_A=COEFF_A ? (COEFF_A.length - 1) : ENV['ORDER_A']&.to_i
ORDER_B=COEFF_B ? (COEFF_B.length - 1) : ENV['ORDER_B']&.to_i
MIN_ORDER=ENV['MIN_ORDER']&.to_i || 0
MAX_ORDER=ENV['MAX_ORDER']&.to_i || 4

OFFSET_X=ENV['OFFSET_X']&.to_i
OFFSET_C=ENV['OFFSET_C']&.to_i
MIN_OFFSET=ENV['MIN_OFFSET']&.to_i
MAX_OFFSET=ENV['MAX_OFFSET']&.to_i || MIN_OFFSET

MIN_PAD=ENV['MIN_PAD']&.to_i || 0
MAX_PAD=ENV['MAX_PAD']&.to_i || 10

PRINT_JSON=ENV['PRINT_JSON'] == '1'

REPEATS=ENV['REPEATS']&.to_i || 2

NO_DEBUG=ENV['DEBUG'] == '0' || ENV['NO_DEBUG'] == '1'

# Print only if Ruby debug flag is set
def dbg(*s)
  puts(*s) if $DEBUG
end

# COPIED FROM MB::M::Polynomial in its very rough debugging state
#
# Returns an Array with the coefficients of the result of dividing this
# polynomial by the +other+ using FFT-based deconvolution.
#
# FIXME: this only works when there is no remainder
# TODO: maybe also add a least-squares division algorithm
def fft_divide(a, b, details: false, offsets: nil, pad_range: 0..10)
  if NO_DEBUG
    # Call the production code
    dbg 'NO DEBUG'
    if details
      return {coefficients: a.fft_divide(b), off_self: nil, off_other: nil, pad: nil}
    else
      return a.fft_divide(b)
    end
  end

  length = MB::M.max(a.order, b.order) + 1

  # TODO: can we just pad to odd length here?
  # Try different padding amounts to minimize or eliminate zero coefficients
  (f1, f2), (off_a, off_b), pad = optimal_pad_fft(
    Numo::DComplex.cast(a.coefficients), Numo::DComplex.cast(b.coefficients),
    min_length: length,
    offsets: offsets || [],
    pad_range: pad_range
  )

  f3 = f1 / f2

  # Check for 0 divided by 0 in the DC coefficient.  Not checking for
  # infinity because if b is a factor of a, then any FFT zero in
  # a must also be present in b.
  if f3[0].abs.nan? || (f1[0].abs.round(6) == 0 && f2[0].abs.round(6) == 0)
    dbg 'DC NAN -- padding and guessing'
    # Guess the DC coefficient by adding more padding and looking at the
    # padded area.
    # The DC coefficient will be zero on a product if any of the factors
    # had a zero DC coefficient.

    (f1, f2), (off_a, off_b), pad = optimal_pad_fft(
      Numo::DComplex.cast(a.coefficients), Numo::DComplex.cast(b.coefficients),
      min_length: length,
      offsets: offsets || [],
      pad_range: (pad + 1)..(pad + 5)
    )

    f3 = f1 / f2
    f3[0] = 0
    n3 = Numo::Pocketfft.ifft(f3)
    d = MB::M.rol(n3, 1 + off_b - off_a)

    # Remove DC offset; first value should be zero since we know we've zero-padded with rightward alignment
    d -= d[0]

    #require 'pry-byebug'; binding.pry # XXX
  else
    n3 = Numo::Pocketfft.ifft(f3)
    d = MB::M.rol(n3, 1 + off_b - off_a)
  end

  n1 = Numo::Pocketfft.ifft(f1)
  n2 = Numo::Pocketfft.ifft(f2)

  # FIXME: maybe this shouldn't round at all (but we still need to detect
  # true zeros from very-near zeros to truncate leading zeros, unless we
  # can use the polynomial orders and assume there is no remainder).
  # TODO: maybe we should change the rounding amount based on the number
  # of coefficients, so that we continue to remove leading zeros as
  # overall precision decreases
  d = MB::M.round(d, 12).to_a

  added1 = d.length - a.coefficients.length
  added2 = d.length - b.coefficients.length

  d2 = MB::M.ltrim(d)

  #require 'pry-byebug'; binding.pry # XXX

  details ? {coefficients: d2, off_self: off_a, off_other: off_b, pad: pad} : d2
end

# Experimental: finds an optimal padding in the time/space domain to
# minimize zeros or small values in the frequency domain.
#
# TODO: figure out if this is just an even vs. odd length thing
#
# +:offsets+ are for hard-coding the offsets in #optimal_shift_fft,
# applied to +narrays+ in order, for testing with bin/fft_offsets.rb.
def optimal_pad_fft(*narrays, min_length: nil, offsets: [], pad_range: 0..10)
  freqmin = nil
  nancount = nil
  zerocount = nil
  badcount = nil
  freq = nil
  off = nil
  idx = nil

  min_length ||= narrays.max(&:length)

  raise "Pad range #{pad_range} is empty" if pad_range.end < pad_range.begin

  for pad in pad_range
    flist = narrays.map.with_index { |n, idx| optimal_shift_fft(MB::M.zpad(n, min_length + pad, alignment: 1.0), pad_xxx: pad, idx_xxx: idx, offset: offsets[idx]) }
    flistmin = flist.map { |f, _idx| f.abs.min }.min
    flistnan = flist.map { |f, _idx| f.isnan.count_1 }.sum
    flistzero = flist.map { |f, _idx| f.eq(0).count_1 }.sum
    flistbad = flist.map { |f, _idx| MB::M.round(f, 6).eq(0).count_1 }.sum
    flistshift = flist.map(&:last)

    dbg 'first round' if freq.nil?
    dbg "listmin #{flistmin}/#{freqmin}"# if freq && flistmin > freqmin
    dbg "listnan #{flistnan}/#{nancount}"# if freq && flistnan < nancount
    dbg "listbad #{flistbad}/#{badcount}"# if freq && flistbad < badcount

    if ffts_better?(freq&.map(&:first), flist.map(&:first), print: "pad #{pad} off #{flistshift}")
      dbg "Pad #{pad} len #{flist.first.first.length} is better than #{idx&.inspect || 'nothing'}"
      freq = flist
      freqmin = flistmin
      nancount = flistnan
      zerocount = flistzero
      badcount = flistbad
      off = flistshift
      idx = pad
    end
  end

  dbg "Best padding for starting length #{min_length}: #{idx} with offsets: #{off}, min abs: #{freqmin} and max #{freq.map(&:first).map(&:abs).map(&:max).max} nan: #{nancount} bad: #{badcount}"

  return freq.map(&:first), off, idx
end

# Experimental: finds an optimal shift in the time/space domain to
# minimize zeros or small values in the frequency domain.
#
# TODO: I'm not expecting this to work, because I expect a sample offset
# to be purely a phase difference.
#
# TODO: Could try different padding lengths instead of different shifts
#
# TODO: Could try minimizing the difference between two ffts so that
# small coefficients line up and don't explode as much when divided.
def optimal_shift_fft(narray, pad_xxx:, idx_xxx:, offset:)
  freq = nil
  idx = nil

  for offset in (offset || 0)..(offset || narray.length / 2)
    f = Numo::Pocketfft.fft(MB::M.rol(narray, offset))
    freq, idx = f, offset if ffts_better?(freq, f)

    f = Numo::Pocketfft.fft(MB::M.ror(narray, offset))
    freq, idx = f, -offset if freq.nil? || f.abs.min > freq.abs.min
  end

  dbg "Best offset for pad #{pad_xxx} idx #{idx_xxx} len #{narray.length}: #{idx} with min #{freq.abs.min} max #{freq.abs.max} nan #{freq.isnan.count} zero #{freq.eq(0).count} bad #{MB::M.round(freq, 12).eq(0).count}"

  return freq, idx
end

# Returns true if the +new+ list of FFTs has fewer NaNs, zeros, or
# near-zeros than the +old+ list.
def ffts_better?(old, new, print: false)
  if old.nil?
    dbg 'better than nothing' if print
    return true if old.nil?
  else
    old = [old] unless old.is_a?(Array)
    new = [new] unless new.is_a?(Array)

    # TODO: Avoid recalculating these values on every iteration
    oldmin = old.map { |f| f.abs.min }.min
    oldnan = old.map { |f| f.isnan.count_1 }.sum
    oldzero = old.map { |f| f.eq(0).count_1 }.sum
    oldbad = old.map { |f| MB::M.round(f, 6).eq(0).count_1 }.sum
    oldodd = old.map { |f| f.length.odd? ? 1 : 0 }.sum

    newmin = new.map { |f| f.abs.min }.min
    newnan = new.map { |f| f.isnan.count_1 }.sum
    newzero = new.map { |f| f.eq(0).count_1 }.sum
    newbad = new.map { |f| MB::M.round(f, 6).eq(0).count_1 }.sum
    newodd = new.map { |f| f.length.odd? ? 1 : 0 }.sum

    # XXX newnan < oldnan || (newnan == oldnan && (newzero < oldzero || (newzero == oldzero && (newbad < oldbad || (newbad == oldbad && false && (newmin > oldmin))))))

    if newnan < oldnan
      dbg "#{print} better because nan" if print
      return true
    elsif newnan == oldnan
      if newbad < oldbad
        dbg "#{print} better because bad" if print
        return true
      elsif newbad == oldbad
        if newodd < oldodd
          dbg "#{print} better because odd" if print
          return true
        elsif newodd == oldodd
          if newmin > oldmin
            dbg "#{print} better because min" if print
            return true
          end
        end
      end
    end
  end

  false
end


def random_polynomial(order)
  c = [0]

  # Make sure first coefficient is nonzero
  c[0] = rand(-100..100) while c[0] == 0 || c.empty?

  for i in 0...order
    # 50/50 chance of a zero
    c << (rand() > 0.5 ? 0 : rand(-100..100))
  end

  MB::M::Polynomial.new(c)
end

# Returns the leftward offset of the +query+ array compared to the +target+
# array.  That is, the value of offset is returned when MB::M.rol(query,
# offset) == target (within some rounding error).
def find_offset(target, query)
  target = MB::M.round(
    MB::M.zpad(target, query.length, alignment: 1),
    6
  )
  query = MB::M.round(query, 6)

  for offset in 0...query.length
    return -offset if MB::M.ror(query, offset) == target
    return offset if MB::M.rol(query, offset) == target
  end

  warn 'No matching offset found'

  nil
end

def aos_to_soa(array_of_hashes)
  hash_of_arrays = {}
  array_of_hashes.each do |h|
    h.each do |k, v|
      hash_of_arrays[k] ||= []
      hash_of_arrays[k] << v
    end
  end
  hash_of_arrays
end


srand(ENV['SEED'].to_i) if ENV['SEED'] && ENV['SEED'] =~ /\A[0-9]+\z/
SEED = Random.respond_to?(:seed) ? Random.seed : Random::DEFAULT.seed

results = []

order_range = MIN_ORDER..MAX_ORDER
order_a_range = (ORDER_A && (ORDER_A..ORDER_A)) || order_range
order_b_range = (ORDER_B && (ORDER_B..ORDER_B)) || order_range

offset_range = (MIN_OFFSET && MAX_OFFSET && (MIN_OFFSET..MAX_OFFSET)) || (0..0)
offset_x_range = (OFFSET_X && (OFFSET_X..OFFSET_X)) || offset_range
offset_c_range = (OFFSET_C && (OFFSET_C..OFFSET_C)) || offset_range

for order_a in order_a_range
  for order_b in order_b_range
    REPEATS.times do
      a = COEFF_A ? MB::M::Polynomial.new(COEFF_A) : random_polynomial(order_a)
      b = COEFF_B ? MB::M::Polynomial.new(COEFF_B) : random_polynomial(order_b)
      c = a * b

      for offset_c in offset_c_range
        for offset_x in offset_x_range
          q = fft_divide(c, b, details: true, offsets: [offset_c, offset_x], pad_range: MIN_PAD..MAX_PAD)
          r = fft_divide(c, a, details: true, offsets: [offset_c, offset_x], pad_range: MIN_PAD..MAX_PAD)

          results << {
            order_a: order_a,
            order_b: order_b,
            orda: a.order,
            ordb: b.order,
            ordc: c.order,
            coeff_a: PRINT_JSON ? MB::U.syntax(a.coefficients) : MB::U.syntax(a.to_s),
            coeff_b: PRINT_JSON ? MB::U.syntax(b.coefficients) : MB::U.syntax(b.to_s),
            q: MB::U.syntax(MB::M.convert_down(q[:coefficients])),
            r: MB::U.syntax(MB::M.convert_down(r[:coefficients])),
            off_c: offset_c,
            off_x: offset_x,
            a_calc: "* #{MB::U.highlight(find_offset(a.coefficients, q[:coefficients]))} *",
            a_off_x: q[:off_self],
            a_off_c: q[:off_other],
            a_pad: q[:pad],
            a_extra: q[:coefficients].length - a.coefficients.length,
            b_calc: "* #{MB::U.highlight(find_offset(b.coefficients, r[:coefficients]))} *",
            b_off_x: r[:off_self],
            b_off_c: r[:off_other],
            b_pad: r[:pad],
            b_extra: r[:coefficients].length - b.coefficients.length,
            a_len: a.coefficients.length,
            b_len: b.coefficients.length,
          }
        end
      end
    end
  end
end

MB::U.headline 'Settings', color: 32
puts MB::U.table(
  aos_to_soa([{
    coeff_a: COEFF_A,
    coeff_b: COEFF_B,

    order_a: ORDER_A,
    order_b: ORDER_B,
    min_order: MIN_ORDER,
    max_order: MAX_ORDER,

    offset_x: OFFSET_X,
    offset_c: OFFSET_C,
    min_offset: MIN_OFFSET,
    max_offset: MAX_OFFSET,

    min_pad: MIN_PAD,
    max_pad: MAX_PAD,

    print_json: PRINT_JSON,
    repeats: REPEATS,

    seed: SEED,
  }]),
  variable_width: true
)

results_table = aos_to_soa(results)
puts MB::U.table(results_table, variable_width: true, print: false)

failures = results.select { |r| r[:a_calc].include?('nil') || r[:b_calc].include?('nil') }
if failures.any?
  STDERR.puts "\n\n#{MB::U.headline("\e[1m#{failures.count}\e[22m FAILED".center(50), color: 31, print: false)}\n\n"
  STDERR.puts "\n\n#{MB::U.headline("Random seed: #{SEED}", print: false)}\n\n"
  STDERR.puts MB::U.table(aos_to_soa(failures), variable_width: true, print: false)
  exit 1
else
  puts "\n\n\e[1;32m#{'PASSED'.center([80, MB::U.width].min)}\e[0m\n\n"
end
