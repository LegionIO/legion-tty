# frozen_string_literal: true

require 'fileutils'
require 'json'
require_relative 'base'
require_relative '../theme'

module Legion
  module TTY
    module Screens
      # rubocop:disable Metrics/ClassLength
      class Config < Base
        MASKED_PATTERNS = %w[vault:// env://].freeze

        def initialize(app, output: $stdout, config_dir: nil)
          super(app)
          @output = output
          @config_dir = config_dir || File.expand_path('~/.legionio/settings')
          @files = []
          @selected_file = 0
          @selected_key = 0
          @viewing_file = false
          @file_data = {}
        end

        def activate
          @files = discover_config_files
        end

        def discover_config_files
          return [] unless Dir.exist?(@config_dir)

          Dir.glob(File.join(@config_dir, '*.json')).map do |path|
            { name: File.basename(path), path: path }
          end
        end

        def render(_width, height)
          lines = [Theme.c(:accent, '  Settings'), '']
          lines += if @viewing_file
                     file_detail_lines(height - 4)
                   else
                     file_list_lines(height - 4)
                   end
          hint = @viewing_file ? '  Enter=edit  b=backup  q=back' : '  Enter=view  e=edit  q=back'
          lines += ['', Theme.c(:muted, hint)]
          pad_lines(lines, height)
        end

        def handle_input(key)
          if @viewing_file
            handle_file_view_input(key)
          else
            handle_file_list_input(key)
          end
        end

        private

        def handle_file_list_input(key)
          case key
          when :up then @selected_file = [(@selected_file - 1), 0].max
                        :handled
          when :down then @selected_file = [(@selected_file + 1), @files.size - 1].max
                          :handled
          when :enter then open_file
                           :handled
          when 'q', :escape then :pop_screen
          else
            :pass
          end
        end

        def handle_file_view_input(key)
          keys = @file_data.keys
          max = [keys.size - 1, 0].max
          case key
          when :up then @selected_key = [(@selected_key - 1), 0].max
                        :handled
          when :down then @selected_key = [(@selected_key + 1), max].max
                          :handled
          when 'e', :enter then edit_selected_key
                                :handled
          when 'b'
            backup_current_file
            :handled
          when 'q', :escape
            @viewing_file = false
            @selected_key = 0
            :handled
          else
            :pass
          end
        end

        def open_file
          return unless @files[@selected_file]

          path = @files[@selected_file][:path]
          @file_data = ::JSON.parse(File.read(path))
          @viewing_file = true
          @selected_key = 0
        rescue ::JSON::ParserError, Errno::ENOENT
          @file_data = { 'error' => 'Failed to parse file' }
          @viewing_file = true
        end

        def edit_selected_key # rubocop:disable Metrics/AbcSize
          keys = @file_data.keys
          return unless keys[@selected_key]

          key = keys[@selected_key]
          current = @file_data[key]
          return if current.is_a?(Hash) || current.is_a?(Array)

          require 'tty-prompt'
          prompt = ::TTY::Prompt.new
          display = masked?(current.to_s) ? '********' : current.to_s
          new_val = prompt.ask("#{key}:", default: display)
          return if new_val.nil? || new_val == '********'

          @file_data[key] = new_val
          return unless validate_config(@file_data)

          save_current_file
        rescue ::TTY::Reader::InputInterrupt, Interrupt
          nil
        end

        def validate_config(data)
          ::JSON.generate(data)
          true
        rescue StandardError => e
          @messages = ["Invalid JSON: #{e.message}"]
          false
        end

        def backup_config(path)
          return unless File.exist?(path)

          FileUtils.cp(path, "#{path}.bak")
        end

        def backup_current_file
          return unless @files[@selected_file]

          path = @files[@selected_file][:path]
          backup_config(path)
          @backup_notice = "Backed up to #{File.basename(path)}.bak"
        end

        def save_current_file
          return unless @files[@selected_file]

          path = @files[@selected_file][:path]
          backup_config(path)
          File.write(path, ::JSON.pretty_generate(@file_data))
        end

        def masked?(val)
          MASKED_PATTERNS.any? { |p| val.to_s.start_with?(p) }
        end

        def file_list_lines(max_height)
          @files.each_with_index.map do |f, i|
            indicator = i == @selected_file ? Theme.c(:accent, '>') : ' '
            "  #{indicator} #{f[:name]}"
          end.first(max_height)
        end

        def file_detail_lines(max_height)
          return ["  #{Theme.c(:muted, 'Empty file')}"] if @file_data.empty?

          name = @files[@selected_file]&.dig(:name) || 'unknown'
          lines = ["  #{Theme.c(:secondary, name)}", '']
          @file_data.each_with_index do |(key, val), i|
            indicator = i == @selected_key ? Theme.c(:accent, '>') : ' '
            display_val = format_value(val)
            lines << "  #{indicator} #{Theme.c(:accent, key)}: #{display_val}"
          end
          lines.first(max_height)
        end

        def format_value(val)
          case val
          when Hash then Theme.c(:muted, "{#{val.size} keys}")
          when Array then Theme.c(:muted, "[#{val.size} items]")
          else
            masked?(val.to_s) ? Theme.c(:warning, '********') : val.to_s
          end
        end

        def pad_lines(lines, height)
          lines + Array.new([height - lines.size, 0].max, '')
        end
      end
      # rubocop:enable Metrics/ClassLength
    end
  end
end
