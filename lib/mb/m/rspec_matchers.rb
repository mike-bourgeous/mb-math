# This file defines RSpec matchers.

require 'rspec/expectations'

# This matcher compares individual elements of arrays of the same size, failing
# if any pair of elements has an absolute value difference greater than or
# equal to +max_delta+.
RSpec::Matchers.define :all_be_within do |max_delta|
  match do |actual|
    na_actual = Numo::NArray.cast(actual)
    na_expected = Numo::NArray.cast(@expected)

    if na_actual.length != na_expected.length
      false
    else
      diff = na_expected - na_actual
      (!diff.respond_to?(:isnan) || diff.isnan.count_1 == 0) && diff.abs.max <= max_delta
    end
  end

  chain :of_array do |expected|
    @expected = expected
  end
end
