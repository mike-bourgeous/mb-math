require 'fileutils'
require 'shellwords'

RSpec.describe MB::M::Plot do
  describe '#plot' do
    let(:data) { {test123: [1, 0, 0, 0, 0], data321: [1, 0, 1, 0, 0, 0]} }

    let(:scatter) {
      {
        scatter123: [
          [0.9, 0.9],
          [-0.9, 0.9],
          [0, 0],
          [-0.9, -0.9],
          [0.9, -0.9],
        ],
        xy321: [
          [-0.9, 0.5],
          [-0.5, -0.5],
          [-0.3, 0.2],
          [-0.7, 0.7],
          [0.9, 0.5],
          [0.5, -0.3],
        ],
      }
    }

    context 'with the dumb terminal type' do
      let(:plot) { MB::M::Plot.terminal(width: 80, height: 50) }

      it 'can plot to an array of lines' do
        begin
          lines = plot.plot(data, print: false)
          expect(lines.length).to be_between(plot.height - 3, plot.height + 2)

          graph = lines.join("\n")
          expect(graph).to include('test123')
          expect(graph).to include('data321')

          # Make sure no colors got mangled by later color replacements
          expect(graph.gsub(/\e\[[0-9;]*[A-Za-z]/, '')).not_to match(/[\[;]/)
        ensure
          plot&.close
        end
      end

      it 'can plot to the terminal' do
        begin
          expect(plot.width).to eq(79)
          expect(plot.height).to eq(25)

          orig_stdout = $stdout
          buf = String.new(encoding: 'UTF-8')
          strio = StringIO.new(buf)

          begin
            # TODO: could use RSpec mocks like expect($stdout).to receive(....)...
            $stdout = strio
            plot.plot(data)
          ensure
            $stdout = orig_stdout
          end

          expect(buf).to include('test123')
          expect(buf).to include('data321')

          # Make sure no colors got mangled by later color replacements
          expect(buf.gsub(/\e\[[0-9;]*[A-Za-z]/, '')).not_to match(/[\[;]/)
        ensure
          $stdout = orig_stdout
          plot&.close
        end
      end

      it 'can plot using columns' do
        lines = plot.plot(data, columns: 2, print: false)
        border_line = lines.first { |l| l.include?('----') }

        # Expect the border to be half the screen width
        expect(border_line.match(/\+---+\+/).to_s.length).to be_between(plot.width / 3, plot.width / 2)

        # Expect the legend of both plots to be on the same line
        legend_line = lines.select { |l| l.include?('data321') }.first
        expect(legend_line).to include('test123')
      end

      it 'can plot using rows' do
        lines = plot.plot(data, columns: 1, rows: 2, print: false)
        border_line = lines.first { |l| l.include?('----') }

        # Expect the border to be half the screen width
        expect(border_line.match(/---+/).to_s.length).to be_between(plot.width * 0.7, plot.width)

        # Expect the legend of both plots not to be on the same line
        legend_line = lines.select { |l| l.include?('data321') }.first
        expect(legend_line).not_to include('test123')

        second_legend = lines.select { |l| l.include?('test123') }.first
        expect(second_legend).not_to include('data321')
      end

      it 'can draw a scatter plot' do
        lines = plot.plot(scatter, columns: 2, rows: 1, print: false)
        lines.map!(&MB::U.method(:remove_ansi))

        # Expect the legend of both plots to be on the same line
        legend_line = lines.select { |l| l.include?('xy321') }.first
        expect(legend_line).to include('scatter123')

        # Expect the plot to contain multiple points in the same column,
        # proving that the scatter plot can move both left and right
        sideways_lines = lines.map { |l| l.ljust(80).chars }.transpose.map(&:join)
        overlapping_lines = sideways_lines.select { |l| l =~ /-(\s+\*+){2,}/ }
        expect(overlapping_lines.count).to be > 4
      end
    end

    ['png', 'svg'].each do |t|
      it "can plot to a/an #{t} image" do
        name = "tmp/plot_test.#{t}"

        FileUtils.mkdir_p('tmp')
        File.unlink(name) rescue nil

        plot = MB::M::Plot.new
        plot.save_image(name, width: 768, height: 317)
        plot.plot(data)
        plot.close

        expect(File.readable?(name)).to eq(true)

        info = JSON.parse(`ffprobe -loglevel 8 -print_format json -show_format -show_streams #{name.shellescape}`, symbolize_names: true)
        expect(info[:streams][0][:width]).to eq(768)
        expect(info[:streams][0][:height]).to eq(317)
        expect(info[:format][:format_name]).to include(t)

        if t == 'svg'
          svg = File.read(name)
          expect(svg).to include('test123')
          expect(svg).to include('data321')
        end
      end
    end
  end
end
