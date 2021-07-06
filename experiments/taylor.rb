#!/usr/bin/env ruby
# Calls out to Sage in a really inefficient way to build the Taylor series
# expansion of a Sage expression.
#
# Usage: $0 "expression" around order

require 'bundler/setup'
require 'pry-byebug'
require 'shellwords'
require 'mb-math'

def sage(cmd)
  `sage -c #{cmd.shellescape}`.strip.lines.map(&:strip)
end

# Computes the numerical derivative of the given +order+ of +f+ at +x+.  The
# +order+ may be a list of orders.
def derivative(f, x, order)
  cmd = [
    "f = #{f}",
    *order.map { |o| "print(derivative(f, #{o})(x=#{x}).n())" }
  ]
  sage(cmd.join("\n")).map { |n|
    Float(n) rescue Complex(n.sub('*I', 'i').gsub(' ', ''))
  }
end

def taylor_coeffs(f, around, order)
  @taylor_memo ||= {}
  @taylor_memo[[f, around, order]] ||= derivative(f, around, (order + 1).times).map.with_index { |num, o|
    denom = o.downto(1).reduce(1, :*)
    num / denom
  }
end

def taylor_expression(f, around, order)
  coeffs = taylor_coeffs(f, around, order)
  terms = coeffs.map.with_index { |c, idx|
    if idx == 0
      c
    else
      if c.real? && c < 0
        prefix = ' - '
      else
        prefix = ' + '
      end

      "#{prefix}#{c.abs} * (x - #{around}) ** #{idx}"
    end
  }
  terms.join
end

#puts sage("f = integrate(-2*atanh(e^(i*x)), x)\nf").inspect
#puts taylor_coeffs('integrate(-2*atanh(e^(i*x)), x)', -1, 4)
#puts taylor_coeffs('ln(x)', Math::E, 4)

raise MB::U.read_header_comment.join if ARGV.length != 3 || ARGV.include?('--help')
f = ARGV[0]
around = Float(ARGV[1]) rescue Complex(ARGV[1])
order = Integer(ARGV[2])

puts "\n\e[1mCoefficients:\e[0m"
puts MB::U.highlight(taylor_coeffs(f, around, order))

puts "\n\e[1mExpression:\e[0m"
puts MB::U.syntax(taylor_expression(f, around, order))
