#!/usr/bin/env ruby
# This is a history of my steps taken to debug an issue with MB::M.kind_sqrt
# for rational complex numbers with large numerators and denominators.
#
# The ultimate cause was converting Rational to Float at one point when we
# wanted to keep them as Rational.
#
# Comment moved from the previously failing spec:
#
# By definition we are creating perfect squares, and yet sometimes the
# intermediate steps produce irrational values.
#
# For example:
#     require 'prime'
#
#     a = (7303r/13063+8846ri/413)
#
#     b = a * a
#     # b = ((-13343929801401483r/29106230010361)+(129204676ri/5395019))
#
#     abs_sq = b.real * b.real + b.imag * b.imag
#     # abs_sq = (178546357533116207952390480015625r/847172625416039298167350321)
#
#     abs = MB::M.kind_sqrt(abs_sq)
#     # abs = (13362123990336126r/29106230010361)
#
#     x_sq = (b.real + abs).quo(2)
#     # x_sq = (18194188934643r/58212460020722)
#
#     y_sq = (-b.real + abs).quo(2) * (b.imag >= 0 ? 1 : -1)
#     # y_sq = (26706053791737609r/58212460020722)
#
#     x = MB::M.kind_sqrt(x_sq)
#     # x = 0.5590599402893822
#
#     y = MB::M.kind_sqrt(y_sq)
#     # y = 21.418886198547213
#
#     r = MB::M.kind_sqrt(b)
#     # r = (0.5590599402893822+21.418886198547213i)
#
#     # The result differs by the last few decimals from the true answer
#     f = Complex(a.real.to_f, a.imag.to_f)
#     # f = (0.5590599402893669+21.418886198547217i)
#
#     # All powers should be even for x_sq and y_sq to be a perfect square but
#     # we see several odds in the numerator.
#     MB::M::Polynomial.print_prime(x_sq)
#     #    3 + 19 + 41 + 6971 + 1116809
#     # ─────────────────────────────────
#     #           2 + 7² + 59² + 13063²
#
#     MB::M::Polynomial.print_prime(y_sq)
#     #     3 + 8902017930579203
#     # ──────────────────────────
#     #    2 + 7² + 59² + 13063²
#
#     # Working backward, here's what we should see:
#     ex_x_sq = a.real * a.real
#     ex_y_sq = a.imag * a.imag
#     MB::M::Polynomial.print_prime(ex_x_sq, prefix: 'expected x_sq')
#     MB::M::Polynomial.print_prime(ex_y_sq, prefix: 'expected y_sq')
#     #                   67² + 109²
#     # expected x_sq  ───────────────
#     #                       13063²
#     #                   2² + 4423²
#     # expected y_sq  ───────────────
#     #                     7² + 59²
#
#     # And for abs (differs by 1 in the numerator from above):
#     ex_abs_x = ex_x_sq * 2 - b.real
#     ex_abs_y = ex_y_sq * 2 + b.real
#     # ex_abs_x = (13362123990336125r/29106230010361)
#     # ex_abs_y = (13362123990336125r/29106230010361)
#
#     # Working back to abs squared, we match the abs_sq value above:
#     ex_abs_sq = ex_abs_x * ex_abs_x
#     # ex_abs_sq = (178546357533116207952390480015625r/847172625416039298167350321)
#     ex_abs_sq == abs_sq
#     # => true
#
#     # So the fault lies in the square root operation!  It must be
#     # giving an incorrect answer for this larger value.


require 'bundler/setup'

require 'mb/math'
require 'prime'

MB::U.sigquit_backtrace

def p(n, a)
  MB::M::Polynomial.print_value(a, prefix: "#{n} =")
  puts
end

a = (7303r/13063+8846ri/413)
p 'a', a

b = a * a
# b = ((-13343929801401483r/29106230010361)+(129204676ri/5395019))
p 'b', b

abs_sq = b.real * b.real + b.imag * b.imag
# abs_sq = (178546357533116207952390480015625r/847172625416039298167350321)
p 'abs_sq', abs_sq

abs = MB::M.kind_sqrt(abs_sq)
# abs = (13362123990336126r/29106230010361)
p 'abs', abs

x_sq = (b.real + abs).quo(2)
# x_sq = (18194188934643r/58212460020722)
p 'x_sq', x_sq

y_sq = (-b.real + abs).quo(2) * (b.imag >= 0 ? 1 : -1)
# y_sq = (26706053791737609r/58212460020722)
p 'y_sq', y_sq

x = MB::M.kind_sqrt(x_sq)
# x = 0.5590599402893822
p 'x', x

y = MB::M.kind_sqrt(y_sq)
# y = 21.418886198547213
p 'y', y

r = MB::M.kind_sqrt(b)
# r = (0.5590599402893822+21.418886198547213i)
p 'r', r

# The result differs by the last few decimals from the true answer
f = Complex(a.real.to_f, a.imag.to_f)
# f = (0.5590599402893669+21.418886198547217i)
p 'f', f

# All powers should be even for x_sq and y_sq to be a perfect square but
# we see several odds in the numerator.
MB::M::Polynomial.print_prime(x_sq)
#    3 + 19 + 41 + 6971 + 1116809
# ─────────────────────────────────
#           2 + 7² + 59² + 13063²

MB::M::Polynomial.print_prime(y_sq)
#     3 + 8902017930579203
# ──────────────────────────
#    2 + 7² + 59² + 13063²

# Working backward, here's what we should see:
ex_x_sq = a.real * a.real
ex_y_sq = a.imag * a.imag
MB::M::Polynomial.print_prime(ex_x_sq, prefix: 'expected x_sq')
MB::M::Polynomial.print_prime(ex_y_sq, prefix: 'expected y_sq')
#                   67² + 109²
# expected x_sq  ───────────────
#                       13063²
#                   2² + 4423²
# expected y_sq  ───────────────
#                     7² + 59²

# And for abs (differs by 1 in the numerator from above):
ex_abs_x = ex_x_sq * 2 - b.real
ex_abs_y = ex_y_sq * 2 + b.real
# ex_abs_x = (13362123990336125r/29106230010361)
# ex_abs_y = (13362123990336125r/29106230010361)
p 'expected abs from x', ex_abs_x
p 'expected abs from y', ex_abs_y

# Working back to abs squared, we match the abs_sq value above:
ex_abs_sq = ex_abs_x * ex_abs_x
# ex_abs_sq = (178546357533116207952390480015625r/847172625416039298167350321)
ex_abs_sq == abs_sq
# => true

# So the fault lies in the square root operation!  It must be
# giving an incorrect answer for this larger value.
