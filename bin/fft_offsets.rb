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

require 'bundler/setup'

require 'mb/util'

require 'mb/math'

ORDER_A=ENV['ORDER_A']&.to_i
ORDER_B=ENV['ORDER_B']&.to_i
MIN_ORDER=ENV['MIN_ORDER']&.to_i || 0
MAX_ORDER=ENV['MAX_ORDER']&.to_i || 4

OFFSET_X=ENV['OFFSET_X']&.to_i
OFFSET_C=ENV['OFFSET_C']&.to_i
MIN_OFFSET=ENV['MIN_OFFSET']&.to_i
MAX_OFFSET=ENV['MAX_OFFSET']&.to_i || MIN_OFFSET

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
order_a_range = (ORDER_A && ORDER_A..ORDER_A) || order_range
order_b_range = (ORDER_B && ORDER_B..ORDER_B) || order_range

offset_range = (MIN_OFFSET && MAX_OFFSET && (MIN_OFFSET..MAX_OFFSET)) || (0..0)
offset_x_range = (OFFSET_X && (OFFSET_X..OFFSET_X)) || offset_range
offset_c_range = (OFFSET_C && (OFFSET_C..OFFSET_C)) || offset_range

for order_a in order_a_range
  for order_b in order_b_range
    REPEATS.times do
      a = random_polynomial(order_a)
      b = random_polynomial(order_b)
      c = a * b

      for offset_c in offset_c_range
        for offset_x in offset_x_range
          q = c.fft_divide(b, details: true, offsets: [offset_c, offset_x])
          r = c.fft_divide(a, details: true, offsets: [offset_c, offset_x])

          results << {
            order_a: order_a,
            order_b: order_b,
            orda: a.order,
            ordb: b.order,
            ordc: c.order,
            coeff_a: MB::U.syntax(a.to_s),
            coeff_b: MB::U.syntax(b.to_s),
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

puts MB::U.table(aos_to_soa(results), variable_width: true)

require 'pry-byebug' ; binding.pry
