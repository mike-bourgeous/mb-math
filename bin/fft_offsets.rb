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

require 'mb/math'

MAX_ORDER=3
REPEATS=3

def random_polynomial(order)
  c = []

  c << rand(-100..100)

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
    return offset if MB::M.rol(query, offset) == target
  end

  warn 'No matching offset found'

  nil
end

results = []

for order_a in 0..MAX_ORDER
  for order_b in 0..MAX_ORDER
    REPEATS.times do
      a = random_polynomial(order_a)
      b = random_polynomial(order_b)
      c = a * b

      q = c.fft_divide(b)
      r = c.fft_divide(a)

      results << {
        order_a: order_a,
        order_b: order_b,
        coeff_a: a.coefficients,
        coeff_b: b.coefficients,
        offset_q: find_offset(a.coefficients, q),
        offset_r: find_offset(b.coefficients, r),
      }
    end
  end
end

puts MB::U.table(results)
