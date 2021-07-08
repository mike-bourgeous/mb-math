# mb-math

[![Tests](https://github.com/mike-bourgeous/mb-math/actions/workflows/test.yml/badge.svg)](https://github.com/mike-bourgeous/mb-math/actions/workflows/test.yml)

Mathematical functions such as range-clamping, interpolation, extrapolation,
etc.  This is companion code to my [educational video series about code and
sound][0].

You might also be interested in [mb-sound][1], [mb-geometry][2], and [mb-util][3].

This code is reasonably well-tested, but I recommend using it for non-critical
tasks, not for making important decisions or for mission-critical data
modeling.  Most of the function implementations target 4 to 6 decimals of
accuracy, which may be too low for some applications.

## Quick start

Clone the repo, follow the [standalone installation instructions
below](#installation-and-usage), and run
`bin/console`.  Use Pry's `ls` command to get a list of what's available, and
the `show-source -d` command to see a function's documentation).


```bash
bin/console
```

```ruby
ls
show-source -d clamp
```

## Examples

For typing convenience, and to avoid conflicting with Ruby's top-level `Math`
module, everything lives under `MB::M` instead of `MB::Math`.

### Smooth interpolation

The `interp` method blends between two `Numeric`s, `Array`s, `Hash`es, or
`Numo::NArray`s.

#### Numbers

```ruby
MB::M.interp(1, 2, 0.5)
# => 1.5
```

#### Hashes

```ruby
a = { x: 0.5, y: 1.5 }
b = { x: 1.0, y: -1.0 }

MB::M.interp(a, b, 0)
# => { x: 0.5, y: 1.5 }

MB::M.interp(a, b, 1)
# => { x: 1.0, y: -1.0 }

MB::M.interp(a, b, 0.5)
# => { x: 0.75, y: 0.25 }
```

#### Smoothed interpolation

The `:func` keyword argument accepts a tweening function.  Anything that
responds to `:call` and returns 0.0 if given 0.0 and 1.0 if given 1.0 can be
used here.

```ruby
a = [-1, -1]
b = [1, 2]
steps = [0, 0.25, 0.5, 0.75, 1]
MB::M.interp(a, b, steps, func: MB::M.method(:smootherstep))
# => [[-1, -1], [-0.79296875, -0.689453125], [0.0, 0.5], [0.79296875, 1.689453125], [1, 2]]
```

#### Linear extrapolation

Note: extrapolation doesn't work as one might expect with `smoothstep` or
`smootherstep`.

```ruby
a = 1
b = 2
MB::M.interp(a, b, 2)
# => 3
```

### Plotting

A simple wrapper around GNUPlot (or any compatible plotter) is provided that
can plot to an image file, a graphical window, or a text console.

The `MB::M::Plot#plot` method takes a `Hash` mapping dataset names to data
values.

```ruby
# Standard plot
p = MB::M::Plot.terminal(width_fraction: 1, height_fraction: 1, width: 40, height: 15)
p.plot({noise: Numo::SFloat.zeros(10).rand(-0.9, 0.9)}, columns: 1, rows: 1)
```

```
   1 +----------------------------+
     |  +  +   +  +  +  +   +  +  |
 0.5 |-+            noise *******-|
     |         *               *  |
     |  *     * *              ** |
   0 |-* *   *  *             * +*|
     | *  *  *   *            *  *|
-0.5 |*+  * *    *           *  +-|
     |     *      *          *    |
     |  +  +   +  ***********  +  |
  -1 +----------------------------+
     0  1  2   3  4  5  6   7  8  9
```

```ruby
# Scatter plot
p = MB::M::Plot.terminal(width_fraction: 1, height_fraction: 1, width: 40, height: 20)
points = (0..(Math::PI * 2)).step(Math::PI / 8).map { |a| [ 0.9 * Math.cos(a), 0.9 * Math.sin(a) ] }
p.xrange(-1, 1)
p.plot({ circle: points })
```

```
    1 +----------------------------+
      |      +       +      +      |
      |             circle ******* |
      |                            |
  0.5 |-+       *********        +-|
      |        *         **        |
      |       *            *       |
    0 |-+    *              *    +-|
      |       *             *      |
      |       *            *       |
      |        ***       **        |
 -0.5 |-+         *******        +-|
      |                            |
      |                            |
      |      +       +      +      |
   -1 +----------------------------+
     -1    -0.5      0     0.5     1
```

### Quadratic roots

```ruby
# f(x) = x^2 + 4
MB::M.quadratic_roots(1, 0, 4)
# => [(0.0+2.0i), (0.0-2.0i)]
```

### Scaling ranges

Scales values or `Numo::NArray`s from one linear range to another,
extrapolating for values beyond the end of the range.

```ruby
MB::M.scale(2, 0..4, 10..12)
# => 11

MB::M.scale(-2, 0..4, 10..12)
# => 9

# Reverse ranges work too
MB::M.scale(Numo::SFloat[0, 1, 2, 3, 4], 1..3, 6..2)
# => Numo::SFloat[8, 6, 4, 2, 0]
```

## Installation and usage

This project contains some useful programs of its own, or you can use it as a
Gem (with Git source) in your own projects.

### Standalone usage and development

First, install a Ruby version manager like RVM.  Using the system's Ruby is not
recommended -- that is only for applications that come with the system.  You
should follow the instructions from https://rvm.io, but here are the basics:

```bash
gpg2 --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
\curl -sSL https://get.rvm.io | bash -s stable
```

Next, install Ruby.  RVM binary rubies are still broken on Ubuntu 20.04.x, so
use the `--disable-binary` option if you are running Ubuntu 20.04.x.

```bash
rvm install --disable-binary 2.7.3
```

You can tell RVM to isolate all your projects and switch Ruby versions
automatically by creating `.ruby-version` and `.ruby-gemset` files (already
present in this project):

```bash
cd mb-math
cat .ruby-gemset
cat .ruby-version
```

Now install dependencies:

```bash
bundle install
```

### Using the project as a Gem

To use mb-math in your own Ruby projects, add this Git repo to your
`Gemfile`:

```ruby
# your-project/Gemfile
gem 'mb-math', git: 'https://github.com/mike-bourgeous/mb-math.git
```

## Testing

Run `rspec` to run all tests.

## Contributing

Pull requests welcome, though development is focused specifically on the needs
of my video series.

## License

This project is released under a 2-clause BSD license.  See the LICENSE file.

## See also

### Dependencies

- [Numo::NArray](https://github.com/ruby-numo/numo-narray)


[0]: https://www.youtube.com/playlist?list=PLpRqC8LaADXnwve3e8gI239eDNRO3Nhya
[1]: https://github.com/mike-bourgeous/mb-sound
[2]: https://github.com/mike-bourgeous/mb-geometry
[3]: https://github.com/mike-bourgeous/mb-util
