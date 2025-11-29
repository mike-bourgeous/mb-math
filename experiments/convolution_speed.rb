#!/usr/bin/env ruby
# Benchmark of FFT vs. direct convolution to see if there's a size below which
# we should use direct convolution.
#
# Usage:
#     RUBYOPT=--jit ./experiments/convolution_speed.rb

require 'bundler/setup'
require 'benchmark'
require 'mb-math'

Benchmark.bmbm do |bench|
  [5, 10, 50, 100, 500, 1000].each do |size|
    a1 = Numo::DFloat.linspace(0, 1, size)
    a2 = MB::M.zpad(Numo::DFloat[1, 0, 0, 1], size)

    bench.report("Pocketfft #{size}") do
      100.times do
        Numo::Pocketfft.fftconvolve(a1, a2)
      end
    end

    bench.report("FFT #{size}") do
      100.times do
        MB::M.fftconvolve(a1, a2)
      end
    end

    bench.report("Direct #{size}") do
      100.times do
        MB::M.convolve(a1, a2)
      end
    end
  end
end
