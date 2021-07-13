#!/usr/bin/env ruby
# Experimenting with an explicit function approximation of a cycloid.

require 'bundler/setup'
require 'pry-byebug'
require 'mb-math'

def cycloid(tmin: -10 * Math::PI, tmax: 10 * Math::PI, xscale: 1, yscale: 1, steps: 1001, alternate: true, power: 1)
  Numo::DFloat.linspace(tmin, tmax, steps).to_a.map { |t|
    x = t - Math.sin(t)
    y = 1 - Math.cos(t)
    y = y ** power * 2.0 / 2.0 ** power if power != 1
    y *= 0.5 * (-1) ** ((t / (2.0 * Math::PI)).floor) if alternate

    [x * xscale, y * yscale]
  }
end

CYCL = cycloid(tmin: -2.0 * Math::PI, tmax: 2.0 * Math::PI)

p = MB::M::Plot.terminal
p.plot(cycloid: CYCL)

def lookup(x)
  idx = CYCL.bsearch_index { |v| v[0] >= x }
  idx = 1 if idx < 1
  idx = CYCL.length - 3 if idx >= CYCL.length - 3

  puts "idx is #{idx}"

  v1 = CYCL[idx]
  return v1[1] if x == v1[0]

  puts 'intp'

  v0 = CYCL[idx - 1]
  v2 = CYCL[idx + 1]
  v3 = CYCL[idx + 2]

  x1 = v1[0]
  x2 = v1[1]
  t = (x - x1) / (x2 - x1)

  v = MB::M.catmull_rom(v0, v1, v2, v3, t, 0.5)

  v[1]
end

q = Numo::DFloat.linspace(-2.0 * Math::PI, 2.0 * Math::PI, 1001).map { |v| lookup(v) }

binding.pry # XXX

puts
