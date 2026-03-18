# frozen_string_literal: true

require_relative '../theme'

module Legion
  module TTY
    module Components
      # rubocop:disable Metrics/ClassLength
      class DigitalRain
        # rubocop:disable Naming/VariableNumber
        FADE_SHADES = %i[
          purple_12 purple_11 purple_10 purple_9 purple_8
          purple_7 purple_6 purple_5 purple_4 purple_3
          purple_2 purple_1
        ].freeze

        HEAD_COLOR = :purple_17
        # rubocop:enable Naming/VariableNumber

        FALLBACK_NAMES = %w[
          hippocampus amygdala prefrontal-cortex cerebellum thalamus hypothalamus
          brainstem synapse apollo tasker scheduler node health telemetry
          conditioner transformer memory dream cortex glia neuron dendrite axon receptor
        ].freeze

        attr_reader :columns, :width, :height

        def initialize(width:, height:, extensions: nil, density: 0.4)
          @width = width
          @height = height
          @density = density
          @extensions = extensions || self.class.extension_names
          @max_frames = 200
          @frame = 0
          @columns = build_columns
        end

        def self.extension_names
          gems = Gem::Specification.select { |s| s.name.start_with?('lex-') }
                                   .map { |s| s.name.sub(/^lex-/, '') }
          gems.empty? ? FALLBACK_NAMES : gems
        rescue StandardError
          FALLBACK_NAMES
        end

        def tick
          @frame += 1
          @columns.each do |col|
            col[:y] += col[:speed]
            reset_column(col) if col[:y] - col[:length] > @height
          end
        end

        def render_frame
          grid = Array.new(@height) { Array.new(@width) { { char: ' ', color: nil } } }
          paint_columns(grid)
          render_grid(grid)
        end

        # rubocop:disable Metrics/AbcSize
        def run(duration_seconds: 7, fps: 18, output: $stdout)
          require 'tty-cursor'
          cursor = TTY::Cursor
          frame_delay = 1.0 / fps
          output.print cursor.hide
          output.print cursor.save
          (duration_seconds * fps).times do
            output.print cursor.restore
            render_frame.each { |line| output.puts line }
            tick
            sleep frame_delay
          end
        ensure
          output.print cursor.show
        end
        # rubocop:enable Metrics/AbcSize

        def done?
          @frame >= @max_frames
        end

        private

        def paint_columns(grid)
          @columns.each do |col|
            pos = col[:x]
            next if pos >= @width

            head_y = col[:y].floor
            col[:chars].each_with_index do |ch, idx|
              row = head_y - idx
              next if row.negative? || row >= @height

              color = pick_color(idx)
              grid[row][pos] = { char: ch, color: color }
            end
          end
        end

        def render_grid(grid)
          grid.map do |row|
            row.map { |cell| cell[:color] ? Theme.c(cell[:color], cell[:char]) : cell[:char] }.join
          end
        end

        def pick_color(idx)
          return HEAD_COLOR if idx.zero?

          idx < FADE_SHADES.size ? FADE_SHADES[idx] : FADE_SHADES.last
        end

        def build_columns
          count = [(@width * @density).ceil, 1].max
          (0...@width).to_a.sample(count).map { |pos| new_column(pos) }
        end

        def new_column(pos)
          { x: pos, y: rand(-@height..0).to_f, speed: rand(0.5..1.5), length: rand(4..14), chars: build_chars }
        end

        def reset_column(col)
          col[:y] = rand(-@height..-1).to_f
          col[:speed] = rand(0.5..1.5)
          col[:length] = rand(4..14)
          col[:chars] = build_chars
        end

        def build_chars
          source = @extensions.sample || 'legion'
          chars = source.chars.reject { |chr| chr == '-' }
          chars = ('a'..'z').to_a if chars.empty?
          Array.new(14) { chars.sample }
        end
      end
      # rubocop:enable Metrics/ClassLength
    end
  end
end
