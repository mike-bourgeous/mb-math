require 'pty'
require 'tempfile'
require 'timeout'

module MB
  module M
    # Super basic interface to GNUplot.  You can plot to the terminal or to a
    # separate window.
    #
    # For 3D surface plots, use type lines for waterfall-like non-occluding
    # lines, zerrorfill for something approximating a fence plot, surface for a
    # grid, and pm3d for a solid plot.
    #
    # Example:
    #
    #     p = MB::M::Plot.terminal
    #
    #     # Debug plotting issues; can also set env PLOT_DEBUG=1
    #     p.debug = true
    #
    #     # Data arrays directly
    #     p.yrange(-1, 3)
    #     p.plot({one: [1,1,1], two: [2,2,2]})
    #
    #     # Data plus info in a Hash
    #     p.plot({a: {data: [1,2,3], yrange: [-3, 3]}, b: {data: [-1, 2, 1]}})
    #
    #     # Surface plot in 3D
    #     p = MB::M::Plot.graphical
    #     p.type = 'pm3d' # or lines or surface
    #
    #     a = Numo::SFloat.linspace(1, 5, 30).map { |v| Math.sin(v) * 3 }.reshape(1, nil) * \
    #       Numo::SFloat.linspace(-10, 10, 30).map { |v| Math.sin(v / 2) * 7 }.reshape(nil, 1)
    #
    #     p.plot({wavy: {data: a, zrange: [-30, 30]}})
    #
    # See README.md for more examples.
    #
    # Created because Numo::Gnuplot was giving an error.
    class Plot
      class StopReadLoop < RuntimeError; end
      class PlotError < RuntimeError; end

      # Creates an ASCII-art plotter sized to the terminal.
      # The :width_fraction and :height_fraction parameters compensate for
      # character aspect ratio so an "80x80" plot will look square.
      def self.terminal(width_fraction: 1.0, height_fraction: 0.5, width: nil, height: nil)
        cols = ENV['PLOT_WIDTH']&.to_i || (((width || MB::U.width) - 1) * width_fraction).round
        rows = ENV['PLOT_HEIGHT']&.to_i || ((height || (MB::U.height - 1)) * height_fraction).round
        Plot.new(terminal: 'dumb', width: cols, height: rows)
      end

      # Creates a graphical plotter.
      def self.graphical(width: 800, height: 800)
        Plot.new(terminal: 'qt', width: width, height: height)
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
        @debug = ENV['PLOT_DEBUG'] == '1'
        @print = true
        @t = Thread.new do read_loop end

        @tempfiles = []

        at_exit do
          cleanup
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

        # FIXME: sometimes the command text leaks out from here into the plot output
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

      # Displays a multi-plot of the given +data+ hash of labels to arrays, with
      # the given number of +columns+ and +rows+ (defaults to a roughly square
      # layout based on number of graphs).
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
      # console.  If false, then terminal plots are returned as an array of
      # lines.
      #
      # Supported dataset plot info keys:
      #   :data - Data (Array or Numo::NArray)
      #   :xrange - X range (Array of two numbers)
      #   :yrange - Y range (Array of two numbers)
      #   :zrange - Z range (Array of two numbers)
      #   :logscale - Use logarithmic X-axis scale
      #   :type - Plot type just for this dataset (e.g. 'lines', 'pm3d', 'surface')
      def plot(data, rows: nil, columns: nil, print: true)
        raise PlotError, 'Plotter is closed' unless @pid

        raise ArgumentError, 'Data must be a hash mapping graph titles to data.' unless data.is_a?(Hash)

        # Don't remove temp files until creating a new plot so that gnuplot can
        # replot when the window is resized/zoomed/etc.
        cleanup

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

        tmps = data.compact.each_with_index.map { |(name, a), idx| [Tempfile.new("plotdata_#{idx}"), name, a] }
        tmps.each do |(file, name, plotinfo)|
          @tempfiles << file

          if plotinfo.is_a?(Hash)
            write_data(file, plotinfo[:data], plotinfo[:type] || @type)
          else
            write_data(file, plotinfo, @type)
          end

          if @debug
            puts "\e[1;36mData file #{name}:#{file.path}: \e[22m\n\t#{File.read(file).lines.join("\t")}\e[0m"
          end
        end

        tmps.each_with_index do |(file, name, plotinfo), idx|
          r, g, b = rand(255), rand(255), rand(255)
          if r+g+b > 255
            r /= 4
            g /= 4
            b /= 4
          end

          if plotinfo.is_a?(Hash)
            array = plotinfo[:data]
          else
            array = plotinfo
            plotinfo = {
              data: plotinfo
            }
          end

          # Set graph range
          if plotinfo[:xrange]
            xrange(*plotinfo[:xrange], false)
          elsif @xrange
            xrange(*@xrange, false)
          elsif array.is_a?(Numo::NArray) && array.ndim == 2
            # Waterfall-like plot or surface plot
            xrange(0, array.shape[1], false)
          else
            xrange(nil, nil, false)
          end

          if plotinfo[:yrange]
            yrange(*plotinfo[:yrange], false)
          elsif @yrange
            yrange(*@yrange, false)
          elsif array.is_a?(Numo::NArray) && array.ndim == 2
            # Waterfall-like plot or surface plot
            yrange(0, array.shape[0], false)
          else
            if array.is_a?(Array) && array.all?(Array)
              xr = array.map { |v| v[0].is_a?(Complex) ? v[0].abs : v[0] }
              range = array.map { |v| v[1].is_a?(Complex) ? v[1].abs : v[1] }
            elsif array.is_a?(Numo::DComplex) || array.is_a?(Numo::SComplex)
              range = array.not_inplace!.abs
            elsif array[0].is_a?(Complex)
              range = array.map(&:abs)
            else
              range = array
            end

            finite = range.to_a.select { |v| v.finite? }
            min = finite.min || -10
            max = finite.max || 10

            min = [0, min.floor].min
            max = max > 0.2 ? max.ceil : 0.1
            yrange(min, max, false)
          end

          if plotinfo[:zrange]
            command "set zrange [#{plotinfo[:zrange][0]}:#{plotinfo[:zrange][1]}]"
          else
            command 'unset zrange'
          end

          if plotinfo[:logscale] == true || (plotinfo[:logscale] != false && @logscale)
            command "set logscale x 10"
          else
            command "unset logscale x"
          end

          if array.is_a?(Numo::NArray) && array.ndim == 2
            # Waterfall-like plot or surface plot
            cmd = 'splot'

            case (plotinfo[:type] || @type)&.to_s
            when 'zerrorfill'
              range = '1:2:3:4:5'

            else
              range = '1:2:3'
            end
          else
            cmd = 'plot'
            range = '1:2'
          end

          command %Q{#{cmd} '#{file.path}' using #{range} with #{plotinfo[:type] || @type} title '#{name}' lt rgb "##{'%02x%02x%02x' % [r,g,b]} fillcolor white"}
        end

        command 'unset multiplot'

        if @terminal == 'dumb'
          print_terminal_plot(print)
        else
          read
          nil
        end
      end

      private

      # Removes temporary files from previous plot(s).
      def cleanup
        @tempfiles.each do |file|
          file.close rescue puts $!
          file.unlink rescue puts $!
        end
        @tempfiles.clear
      end

      def print_terminal_plot(print)
        lines = nil
        3.times do
          buf = read.drop_while { |l|
            l.include?('plot>') ||
              (l.strip.start_with?(/[[:alpha:]]/) && !l.match?(/[-+*]{3,}/)) ||
              l =~ /^\s*unset multiplot\s*$/
          }[0..-2]
          start_index = buf.rindex { |l| l.include?('plot>') }
          raise "Error: no plot was found within #{buf}" unless buf.count > 3 || start_index
          start_index ||= 0
          lines = buf[(start_index + 2)..-1]

          # TODO: use wait_for to make sure we have a full plot
          break if lines
          sleep 0.1
        end

        row = 0
        in_graph = false
        lines.map!.with_index { |l, idx|
          if l.match?(/\+-{10,}\+/)
            if in_graph
              in_graph = false
              row += 1
            else
              in_graph = true
              l = "\n#{l}"
            end
          end

          clr = (row + 1) % 6 + 31
          l.gsub(/\s+([+-]?\d+(\.\d+)?\s*){1,}/, "\e[1;35m\\&\e[0m")
            .gsub(/([[:alnum:]_-]+ ){0,}[*]+/, "\e[1;#{clr}m\\&\e[0m")
            .gsub(/(?<=[|])-[+]| [+] |[+]-(?=[|])/, "\e[1;35m\\&\e[0m")
            .gsub(/[+]-+[+]|[|]/, "\e[1;30m\\&\e[0m")
        }

        if lines.any? { |l| l.include?('plot>') } # XXX seeing some spurious lines above graphs
          puts "\e[1;31mBUG: prompt lines present in graph??\e[0m"
          puts MB::U.highlight(lines)
          binding.pry
        end

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

          STDERR.puts "\e[33mGNUPLOT: \e[1m#{line}\e[0m" if @debug
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

      # Writes data to a temporary file.  Plotting larger amounts of data is faster
      # if the data is written to a file, rather than input on the gnuplot
      # commandline.
      def write_data(file, array, type)
        last_y = 0

        case
        when array.is_a?(Numo::NArray) && array.ndim == 2
          # Waterfall-like plot or surface plot
          case type
          when 'zerrorfill'
            # fence plot
            array.not_inplace!.each_with_index do |z, y, x|
              file.puts "\n\n" if y != last_y
              file.puts "#{x}\t#{y}\t0\t0\t#{z}"
              last_y = y
            end

          else
            array.each_with_index do |z, y, x|
              if y != last_y
                # Break apart rows to give a waterfall-type plot when type is lines
                file.puts if type == 'lines'
                file.puts
              end

              file.puts "#{x}\t#{y}\t#{z}"

              last_y = y
            end
          end

        when array.is_a?(Numo::NArray) || array.is_a?(Array)
          # Standard 1D/2D plot
          array.each_with_index do |value, idx|
            idx, value = value if value.is_a?(Array)
            value = value.abs if value.is_a?(Complex)
            file.puts "#{idx}\t#{value}"
          end

        else
          raise ArgumentError, "Received unsupported data type #{array.class}; pass Array or Numo::NArray for :data"
        end

        file.close
      end
    end
  end
end
