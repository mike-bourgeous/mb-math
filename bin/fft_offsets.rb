#!/usr/bin/env ruby
# Experiment to understand array offsets after FFT-based deconvolution.
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
          q = c.fft_divide(b, details: true, offsets: [offset_c, offset_x], pad_range: MIN_PAD..MAX_PAD)
          r = c.fft_divide(a, details: true, offsets: [offset_c, offset_x], pad_range: MIN_PAD..MAX_PAD)

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

MB::U.headline "Random seed: #{Random::DEFAULT.seed}"
puts

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
  }]),
  variable_width: true
)

results_table = aos_to_soa(results)
puts MB::U.table(results_table, variable_width: true, print: false)

failures = results.select { |r| r[:a_calc].include?('nil') || r[:b_calc].include?('nil') }
if failures.any?
  STDERR.puts "\n\n#{MB::U.headline("\e[1m#{failures.count}\e[22m FAILED", color: 31, print: false)}\n\n"
  STDERR.puts MB::U.table(aos_to_soa(failures), variable_width: true, print: false)
  exit 1
end
