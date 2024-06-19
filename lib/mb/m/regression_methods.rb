module MB
  module M
    module RegressionMethods
      # Performs linear regression on the given +data+ NArray.  Returns an
      # array containing [m, b] from the equation y = m*x+b, where x is the
      # array index.  For a 1D NArray, m and b will be floating point numbers.
      #
      # TODO: Support 2D+ regression and return vectors for m and b?  Support
      # x/y scatter datasets?
      #
      # References:
      # - https://thoughtbot.com/blog/linear-regression-using-dataframes-in-ruby
      def linear_regression(data)
        xmean = data.length / 2.0
        ymean = data.mean

        # TODO: can we get rid of xdiff?
        xdiff = Numo::Int64.linspace(0, data.length - 1, data.length) - xmean
        ydiff = data - ymean
        product = xdiff * ydiff
        psum = product.sum

        xsq = xdiff ** 2
        ysq = ydiff ** 2

        xsum = xsq.sum
        ysum = ysq.sum

        slope = psum / ysum

        # FIXME: specs fail
        [slope, ymean - slope * xmean]
      end
    end
  end
end
