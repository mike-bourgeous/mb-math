#!/usr/bin/env ruby
# Prints the steps of synthetic division of two polynomials.
# (C)2024 Mike Bourgeous
#
# This is based on an earlier state of the code from the MB::M::Polynomial
# class prior to optimization and cleanup.
#
# Pass numerator coefficients, then a slash, then denominator coefficients, as
# command line arguments.  Include all coefficients including zeros.  If run
# with no arguments, generates random polynomials to divide.
#
# Usage:
#     # Step up one row of Pascal's triangle
#     $0 1 4 6 4 1 / 1 1
#
#     # Complex, rational, and floating point numbers work too
#     $0 1/2 6/2 15 -20 15 6i 1.5 / 2 3 3 '1/5i'

require 'bundler/setup'

require 'mb/util'
require 'mb/math'

raise MB::U.read_header_comment.join.gsub('$0', "\e[1m#{$0}\e[0m") if ARGV.include?('--help')

class SyntheticDivisionDemo
  def initialize(num, denom)
    @num = num
    @denom = denom

    @left_count = @denom.length - 1
    @right_count = @num.length
    @row_count = @denom.length

    @rows = Array.new(@row_count) { { left: Array.new(@left_count), right: Array.new(@right_count) } }
    @scale = Array.new(@left_count)
    @result = Array.new(@right_count)

    @skip_pause = false
  end

  # Illustrates polynomial synthetic division on the console using the
  # coefficients given to the constructor.
  #
  # References:
  # https://en.wikipedia.org/wiki/Synthetic_division
  def long_divide
    # Synthetic division uses as many rows above the line as the order of the
    # divisor, plus one.  The first row contains the coefficients of the
    # dividend, and each following row holds one of the divisor coefficients
    # (except the highest order coefficient).
    #
    # Each row has as many columns as the sum of the two polynomial orders plus
    # one.  The first N columns are for the divisor, and the remaining M
    # columns are for the dividend.

    print_table 'Start with O(denom)+2 rows and O(num)+O(denom)+1 columns'

    # The first row on the right is just the coefficients of the dividend
    @rows[0][:right].replace(@num)

    print_table 'Write the numerator coefficients in the top row'

    c0 = @denom[0] || 1

    # The colunms on the left are the remaining coefficients of the denominator
    @denom[1..-1]&.each&.with_index do |c, idx|
      @rows[-(idx + 1)][:left][idx] = -c
    end

    print_table 'Negate and write all but the first denominator coefficients diagonally'

    # The @scale part on the left is the first coefficient of the denominator
    @scale[-1] = MB::M::Polynomial.hlpoly("\u00f7 #{MB::M::Polynomial.num_str(c0, unicode: true)}", '1;35')

    print_table 'Write the first denominator coefficient below'

    for col in 0...@right_count
      # Sum the completed column
      @result[col] = @rows.map { |r| r[:right][col] || 0 }.sum

      print_table "Sum column #{col}"

      # Stop writing diagonals and scaling sum if the diagonal will fall
      # off the right (this means we're working on the remainder)
      if col + @left_count >= @right_count
        next
      end

      # Scale sum by leading coefficient of divisor (non-monic)
      if c0 != 1
        sum = @result[col]
        sum = sum.quo(c0)
        @result[col] = MB::M.convert_down(sum)
      end

      print_table "Scale the column #{col} result by the first denominator coefficient"

      # Fill diagonal
      @left_count.times do |idx|
        @rows[-(idx + 1)][:right][col + idx + 1] = @result[col] * -@denom[idx + 1]
      end

      print_table "Multiply to fill diagonal #{col}"
    end

    print_table 'Done', pause: false

    if @left_count == 0
      quotient = @result
      remainder = [0]
    elsif @left_count >= @result.length
      quotient = [0]
      remainder = @result
    else
      remainder = @result[-@left_count..-1]
      quotient = @result[0...-@left_count]
    end

    return quotient, remainder
  end

  # Prints the current state of the synthetic division table, highlighting any
  # values that have changed since the last display.
  def print_table(title, pause: true)
    new_values = @rows.map { |r|
      r[:left].map { |v| v && MB::M::Polynomial.hlpoly(v, '1;35') } +
        r[:right].map { |v| v && MB::M::Polynomial.hlpoly(v, '1;36') }
    }
    new_values += [@scale + @result.map { |v| v && MB::M::Polynomial.hlpoly(v, '1;32') }]

    @old_values ||= new_values

    highlighted_values = new_values.map.with_index { |row, rowidx|
      row.map.with_index { |v, colidx|
        if @old_values[rowidx][colidx] == v
          v
        else
          "\e[1;48;5;23m#{v}\e[49m"
        end
      }
    }

    @old_values = new_values

    puts "\n\n\e[J"
    MB::U.table(
      highlighted_values,
      header: title,
      separate_rows: true,
      variable_width: 8,
      unicode: true
    )

    if pause
      if @skip_pause
        sleep 0.5
      else
        puts "\n\n\n\e[1;33mPress Enter\e[22m (or type 'go' to speed through)\e[0m\e[J"
        @skip_pause = gets&.strip == 'go'
      end

      # This is the number of header lines to skip past
      STDOUT.write("\e[10H")
    end
  end
end

def read_coeff_args
  coeffs = []
  while ARGV[0] && ARGV[0] =~ /\A([0-9+\-*i().e]+|.+\/.+)\z/
    coeffs << MB::M.convert_down(Complex(ARGV.shift))
  end
  coeffs
end

num_coeffs = read_coeff_args
if ARGV[0] == '/'
  ARGV.shift
  denom_coeffs = read_coeff_args
else
  denom_coeffs = []
end

a = MB::M::Polynomial.random(7, complex: ENV['COMPLEX'] == '1')
b = MB::M::Polynomial.random(4, complex: ENV['COMPLEX'] == '1')
c = MB::M::Polynomial.random(3, complex: ENV['COMPLEX'] == '1')

if num_coeffs.empty? && (denom_coeffs.nil? || denom_coeffs.empty?)
  puts "Generating: \e[1;35m[#{a}]\e[0m * \e[1;36m[#{b}]\e[0m + \e[1;33m[#{c}]\e[0m"
end

numerator = num_coeffs.empty? ? a * b + c : MB::M::Polynomial.new(num_coeffs)
denominator = denom_coeffs.empty? ? b : MB::M::Polynomial.new(denom_coeffs)

num_str = numerator.to_s(unicode: true)
denom_str = denominator.to_s(unicode: true)

puts "\e[H\e[J"
puts "\e[33mSynthetic Division Demo from mb-math: \e[1mhttps://github.com/mike-bourgeous/mb-math\e[0m"
puts "\nSee Wikipedia: \e[1mhttps://en.wikipedia.org/wiki/Synthetic_division#For_non-monic_divisors\e[0m"
puts "\n\n"
MB::M::Polynomial.print_over(numerator, denominator, prefix: 'Calculating:')

quotient, remainder = SyntheticDivisionDemo.new(numerator.coefficients, denominator.coefficients).long_divide

quo_poly = MB::M::Polynomial.new(quotient).to_s(unicode: true)
rem_poly = MB::M::Polynomial.new(remainder).to_s(unicode: true).rjust(quo_poly.length)

MB::U.headline('Answer'.ljust(40), underline: "\u2550")

MB::U.table(
  {
    "\e[1;36mNumerator\e[0m" => MB::M::Polynomial.hlpoly(num_str, '1;36'),
    "\e[1;35mDenominator\e[0m" => MB::M::Polynomial.hlpoly(denom_str, '1;35'),
    "\e[1;32mQuotient\e[0m" => MB::M::Polynomial.hlpoly(quo_poly, '1;32'),
    "\e[1;33mRemainder\e[0m" => MB::M::Polynomial.hlpoly(rem_poly, '1;33'),
  }.to_a,
  variable_width: true,
  header: false,
  unicode: true
)
