require 'pty'
require 'tempfile'
require 'timeout'
require 'shellwords'

module MB
  module M
    # Super basic interface to GNUplot.  You can plot to the terminal or to a
    # separate window.
    #
    # See README.md for a couple of examples.
    #
    # TODO: more examples
    #
    # Created because Numo::Gnuplot was giving an error.
    class Plot
      class StopReadLoop < RuntimeError; end
      class PlotError < RuntimeError; end

      # Creates an ASCII-art plotter sized to the terminal.
      def self.terminal(width_fraction: 1.0, height_fraction: 0.5, width: nil, height: nil)
        cols = ENV['PLOT_WIDTH']&.to_i || (((width || MB::U.width) - 1) * width_fraction).round
        rows = ENV['PLOT_HEIGHT']&.to_i || (((height || MB::U.height) - 1) * height_fraction).round
        Plot.new(terminal: 'dumb', width: cols, height: rows)
      end

      # The plot type (e.g. 'lines', 'boxes', 'pm3d').
      attr_accessor :type

      # The window title (change with #terminal).
      attr_reader :title

      # If true, all incoming lines from gnuplot are printed to the terminal.
      attr_accessor :debug

      # If false, the dumb terminal plotter does not print to the terminal.
      attr_accessor :print

      # The dimensions of the terminal or graphical plot window, in characters
      # or pixels respectively.
      attr_reader :width, :height

      # Use a longer +timeout+ if you will be plotting lots of data.
      def initialize(terminal: ENV['PLOT_TERMINAL'] || 'qt', title: nil, width: ENV['PLOT_WIDTH']&.to_i || 800, height: ENV['PLOT_HEIGHT']&.to_i || 800, timeout: 5)
        @width = width
        @height = height
        @xrange = nil
        @yrange = nil
        @title = title
        @rows = nil
        @cols = nil
        @logscale = false
        @type = 'lines'
        @timeout = timeout

        @read_mutex = Mutex.new

        @buf = []
        @buf_idx = 0 # offset in the buf where we left off looking for something
        @stdout, @stdin, @pid = PTY.spawn('gnuplot')

        @run = true
        @debug = false
        @print = true
        @t = Thread.new do read_loop end

        at_exit do
          @timeout = 1
          close rescue nil
        end

        # Wait for any output
        wait_for('')

        terminal(terminal: terminal, title: title)
      rescue Errno::ENOENT => e
        raise PlotError, "Make sure GNUplot is installed for plotting (see the instructions in the README)"
      end

      # Returns an Array with all lines of output from gnuplot up to this point and
      # clears the buffer.
      def read
        @read_mutex.synchronize {
          @buf_idx = 0
          @buf.dup.tap { @buf.clear }
        }
      end

      # Sends the given command to gnuplot, then waits for the gnuplot command
      # prompt to return.
      def command(cmd)
        raise PlotError, 'Plot is closed' unless @stdin

        @stdin.puts cmd
        wait_prompt # wait for the 'gnuplot>' that came before the current line

        @stdin.puts # 'gnuplot>' isn't printed with a new line, so make a new line
        wait_prompt
      end

      # Change the terminal type to +terminal+ (defaults to 'qt') with window title
      # +title+ (nil for unchanged) and the given size (also nil for unchanged).
      def terminal(terminal: 'qt', title: nil, width: nil, height: nil)
        @terminal = terminal
        @title = title || @title || ''
        @width = width || @width || 800
        @height = height || @height || 800
        command "set terminal #{terminal} #{title ? "title #{@title.inspect}" : ""} size #{@width},#{@height} enhanced font 'Helvetica,10'"
      end

      # Switches the GNUplot terminal to write to a PNG file on the next plot.
      def save_image(filename, width: 1080, height: 1080)
        ext = File.extname(filename)
        case ext
        when '.svg'
          term = 'svg'
        when '.png'
          term = 'pngcairo'
        else
          raise PlotError, "Unknown file extension #{ext}"
        end

        terminal(terminal: term, width: width, height: height, title: nil)
        command "set output #{filename.inspect}"
      end

      # Stops gnuplot and closes the connecting pipes.
      def close
        return if @pid.nil?

        pid = @pid
        @pid = nil

        err = nil

        if @stdin
          @stdin.puts 'exit'
          @stdin.puts ''
          @stdin.puts ''
          @stdin.flush
          wait_for(/plot>[[:space:]]*exit/, join: true) rescue err ||= $!

          @stdin.close
          @stdin = nil
        end

        begin
          begin
            Timeout.timeout(@timeout) do
              Process.wait(pid)
            end
          rescue Timeout::Error
            Process.kill(:TERM, pid)
            Timeout.timeout(@timeout) do
              Process.wait(pid)
            end
          end
        rescue => e
          err ||= $!
        end

        @run = false
        @t&.raise StopReadLoop, 'Closing the plotter' if @t&.alive?
        @stdout&.close
        @t&.join rescue err ||= $!
        @stdout = nil

        @rows = nil
        @cols = nil

        raise err if err
      end

      # Returns true if the plotter has been closed with #close, or because the
      # terminal window was resized.
      def closed?
        @stdin.nil?
      end

      def logscale(enabled = true)
        @logscale = enabled
      end

      # Sets xrange of the next plot (not kept after a reset) also don't rely on this documentation
      def xrange(min, max, keep=true)
        @xrange = [min, max] if keep

        if min.nil? || max.nil?
          command 'unset xrange'
        else
          command "set xrange [#{min}:#{max}]"
        end
      end

      # Sets yrange of the next plot (not kept after a reset) also don't rely on this documentation
      def yrange(min, max, keep=true)
        @yrange = [min, max] if keep

        if min.nil? || max.nil?
          command 'unset yrange'
        else
          command "set yrange [#{min}:#{max}]"
        end
      end

      # For internal use by #plot.  Generates the string of arguments for the
      # GNUPlot plot command for the given +plot+, which may be:
      def plot_string(plot_type, tempfile, data)
      end

      # For internal use by #plot.  Determines whether a dataset is a
      # sequential sample plot, a scatter plot, a function, or a group of the
      # above.
      def detect_type(data, depth: 0)
        case data
        when Array
          return :array_numeric if data.all?(Numeric)

          if array.all?(Array)
            return :array_scatter if data.all? { |a| a.length == 2 && a.all?(Numeric) }
          end

          if depth == 0
            nested_types = data.map { |a| detect_type(a, depth: depth + 1) }
            return :array_overlay if nested_types.all?(Symbol)
          end

          raise ArgumentError, 'Unable to detect plot type(s) within Array'

        when Numo::NArray
          return :narray_numeric if data.ndim == 1
          return :narray_scatter if data.ndim == 2 && data.shape[0] == 2

          raise ArgumentError, "Unsupported shape #{data.shape} for Numo::NArray dataset"

        when ::MB::M::Plot::Function
          return :function

        else
          raise ArgumentError, "Unsupported dataset type #{data.class}"
        end
      end

      # For internal use by #plot.  Determines a (hopefully) suitable X range
      # for the given +data+.
      def detect_xrange(data)
        # TODO: would minmax or minmax_by be faster if we could skip infinities?
        if data.is_a?(Array) && data.all?(Array)
          range = data.map { |v| v[0].is_a?(Complex) ? v[1].abs : v[1] }

        elsif data.is_a?(Numo::NArray)
          if data.ndim != 1
            range = data.not_inplace![1, nil]
            range = range.abs if range[0].is_a?(Complex)
          end
        end

        # Let GNUplot pick xrange if this isn't a scatter plot
        return [] if range.nil?

        finite = range.to_a.select { |v| v.finite? }
        min = finite.min || -10
        max = finite.max || 10

        min = [0, min.floor].min
        max = max > 0.2 ? max.ceil : 0.1

        [min, max]
      end

      # For internal use by #plot.  Automatically determines a (hopefully)
      # suitable Y range for the given +data+.
      def detect_yrange(data)
        # TODO: would minmax or minmax_by be faster if we could skip infinities?
        if data.is_a?(Array) && data.all?(Array)
          range = data.map { |v| v[1].is_a?(Complex) ? v[1].abs : v[1] }

        elsif data.is_a?(Numo::NArray)
          if data.ndim == 1
            range = data.not_inplace!
          else
            range = data.not_inplace![1, nil]
          end
          range = range.abs if range[0].is_a?(Complex)

        elsif data[0].is_a?(Complex)
          range = data.map(&:abs)

        else
          range = data
        end

        finite = range.to_a.select { |v| v.finite? }
        min = finite.min || -10
        max = finite.max || 10

        min = [0, min.floor].min
        max = max > 0.2 ? max.ceil : 0.1

        [min, max]
      end

      # For internal use by #plot.  Sends the commands for one plot to GNUplot
      # including range, logscale, and plot.
      #
      # Returns an array with any temporary files created to prevent garbage
      # collection from deleting them before GNUplot reads the data.
      def plot_single(name, plotinfo)
        # TODO: allow overlaying multiple plots on one graph

        data = plotinfo[:data]
        plot_type = detect_type(data)
        puts "Plot type is #{MB::U.highlight(plot_type)}" # XXX

        tmpfiles = []
        plot_strings = []
        data = [data] unless plot_type == :array_overlay
        data.each do |d|
          d_type = plot_type == :array_overlay ? detect_type(d) : plot_type

          file = Tempfile.new("plotdata_#{name.to_s.shellescape}")
          tmpfiles << file
          write_data(file, d)

          r, g, b = rand(255), rand(255), rand(255)
          if r+g+b > 255
            r /= 4
            g /= 4
            b /= 4
          end

          # Set graph range
          # TODO: Coalesce ranges from overlaid datasets
          plot_xrange = plotinfo[:xrange] || @xrange || detect_xrange(d)
          plot_xrange = [plot_xrange.begin, plot_xrange.end] if plot_xrange.is_a?(Range)
          xrange(plot_xrange[0], plot_xrange[1], false)

          plot_yrange = plotinfo[:yrange] || @yrange || detect_yrange(d)
          plot_yrange = [plot_yrange.begin, plot_yrange.end] if plot_yrange.is_a?(Range)
          yrange(plot_yrange[0], plot_yrange[1], false)

          if plotinfo[:logscale] == true || (plotinfo[:logscale] != false && @logscale)
            command "set logscale x 10"
          else
            command "unset logscale x"
          end

          if d.is_a?(::MB::M::Plot::Function)
            raise NotImplementedError, 'TODO: support plotting functions'
          else
            plot_strings << %Q{'#{file.path}' using 1:2 with #{@type} title '#{name}' lt rgb "##{'%02x%02x%02x' % [r,g,b]}}
          end
        end

        command %Q{plot #{plot_strings.join(', ')}"}

        tmpfiles.compact
      end

      # Displays a multi-plot of the given +data+ Hash of labels to datasets,
      # with the given number of +columns+ and +rows+ (defaults to a roughly
      # square layout based on number of graphs).
      #
      # A dataset may be:
      # - An Array of Numeric or a 1D Numo::NArray to use indexes as X
      # - An Array of two-number Arrays or a 2xN Numo::NArray for X/Y plot
      # - An MB::M::Plot::Function for a computed function (1D or parametric)
      # - Or, an Array of any of the above to overlay plots on one graph
      #
      # If each data element is Numeric, then the graph X axis is array index.
      # If each data element is a two-element Array, then the graph X axis is
      # the first element and the Y axis is the second element.  Thus, scatter
      # plots may be drawn by passing an array of 2D arrays instead of an array
      # of numbers.
      #
      # If the read buffer (see #read) gets larger than 1100 lines, it will be
      # trimmed to the most recent 1000 lines to prevent unbounded memory
      # growth.  But if the terminal type is 'dumb', then the buffer will be
      # cleared before and after plotting so the resulting plot can be
      # displayed.
      #
      # If +:print+ is true, then 'dumb' terminal plots are printed to the
      # console.  If false, then plots are returned as an array of lines.
      def plot(data, rows: nil, columns: nil, print: true)
        raise PlotError, 'Plotter is closed' unless @pid
        raise ArgumentError, 'Pass a Hash mapping labels to datasets' unless data.is_a?(Hash)

        @read_mutex.synchronize {
          if @terminal == 'dumb'
            @buf.clear
            @buf_idx = 0
          elsif @buf.length > 1100
            remove = @buf.length - 1000
            @buf_idx -= remove
            @buf_idx = 0 if @buf_idx < 0
            @buf.shift(remove)
          end
        }

        rows ||= columns.nil? ? Math.sqrt(data.size).ceil : (data.size.to_f / columns).ceil
        cols = columns || (data.size.to_f / rows).ceil

        set_multiplot(rows, cols)

        tmpfiles = []

        data.each do |label, plotinfo|
          begin
            plotinfo = { data: plotinfo } unless plotinfo.is_a?(Hash)
            tmpfiles.concat(
              plot_single(label, plotinfo)
            )
          rescue => e
            raise PlotError, "Error plotting #{label} dataset: #{e.message}"
          end
        end

        unset_multiplot

        if @terminal == 'dumb'
          print_terminal_plot(print)
        end

      ensure
        tmpfiles&.map { |(file, data)|
          file&.close rescue puts MB::U.highlight($!)
          file&.unlink rescue puts MB::U.highlight($!)
        }
      end

      private

      def print_terminal_plot(print)
        buf = read.reject { |l| l.empty? || l.include?('plot>') || l.strip.start_with?(/[[:alpha:]]/) }
        start_index = buf.index { |l| l.include?('+----') }
        lines = buf[start_index..-1]

        row = 0
        in_graph = false
        lines.map!.with_index { |l, idx|
          if l.include?('+----')
            if in_graph
              in_graph = false
              row += 1
            else
              in_graph = true
              l = "\n#{l}"
            end
          end

          clr = (row + 1) % 6 + 31
          l.gsub(/^\s+([+-]?\d+(\.\d+)?\s*){1,}/, "\e[1;35m\\&\e[0m")
            .gsub(/([[:alnum:]_-]+ ){0,}[*]+/, "\e[1;#{clr}m\\&\e[0m")
            .gsub(/(?<=[|])-[+]| [+] |[+]-(?=[|])/, "\e[1;35m\\&\e[0m")
            .gsub(/[+]-+[+]|[|]/, "\e[1;30m\\&\e[0m")
        }

        binding.pry if lines.any? { |l| l.include?('plot') } # XXX seeing some spurious lines above graphs

        if @print && print
          puts lines
        else
          lines
        end
      end

      # Waits for the gnuplot prompt.
      def wait_prompt(timeout: nil)
        wait_for('plot>', timeout: timeout)
      end

      # Waits for the given +text+ output from gnuplot (which must occur on a
      # single line unless +:join+ is true), or a sequence of matching lines if
      # +text+ is an Array, with a default +timeout+ of 5s (or whatever was
      # passed to the constructor).
      def wait_for(text, join: false, timeout: nil)
        timeout ||= @timeout

        start = ::MB::U.clock_now
        while (::MB::U.clock_now - start) < timeout
          # @stdout.expect is locking up on #eof? when combined with the read
          # thread, so we'll just do our own thing.
          @read_mutex.synchronize {
            # Maybe the text already arrived in the background read thread
            idx = @buf_idx
            @buf_idx = @buf.length unless join

            buf_subset = @buf[idx..-1]

            case text
            when String
              return if buf_subset.any? { |line| line.include?(text) } || (join && buf_subset.join.include?(text))
            when Regexp
              return if buf_subset.any? { |line| line =~ text } || (join && buf_subset.join =~ text)
            else
              raise PlotError, "Invalid text #{text.inspect}"
            end
          }

          Thread.pass
        end

        raise PlotError, "Timed out waiting for #{text.inspect} after #{timeout} seconds: #{@buf}"
      end

      # Background thread runs this to read GNUplot's output.
      def read_loop
        while @run
          line = @stdout.readline.rstrip
          @read_mutex.synchronize {
            @buf << line
          }

          puts "\e[33mGNUPLOT: \e[1m#{line}\e[0m" if @debug
        end

      rescue StopReadLoop, Errno::EIO
        # Ignore
      end

      def set_multiplot(rows, cols)
        if rows != @rows || cols != @cols
          @rows = rows
          @cols = cols
          command 'unset multiplot' if @rows && @cols
        end
        command "set multiplot layout #{rows}, #{cols}"
      end

      def unset_multiplot
        @rows = nil
        @cols = nil
        command 'unset multiplot'
      end

      # Writes data to a temporary file.  Plotting larger amounts of data is faster
      # if the data is written to a file, rather than input on the gnuplot
      # commandline.
      def write_data(file, array)
        array.each_with_index do |value, idx|
          idx, value = value if value.is_a?(Array)
          value = value.abs if value.is_a?(Complex)
          file.puts "#{idx}\t#{value}"
        end

        file.close
      end
    end
  end
end

require_relative 'plot/function'
