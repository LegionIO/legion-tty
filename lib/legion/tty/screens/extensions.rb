# frozen_string_literal: true

require_relative 'base'
require_relative '../theme'

module Legion
  module TTY
    module Screens
      # rubocop:disable Metrics/ClassLength
      class Extensions < Base
        CORE = %w[lex-node lex-tasker lex-scheduler lex-conditioner lex-transformer
                  lex-synapse lex-health lex-log lex-ping lex-metering lex-llm-gateway
                  lex-codegen lex-exec lex-lex lex-telemetry lex-audit lex-detect].freeze

        AI = %w[lex-claude lex-openai lex-gemini].freeze

        SERVICE = %w[lex-http lex-vault lex-github lex-consul lex-kerberos lex-tfe
                     lex-redis lex-memcached lex-elasticsearch lex-s3].freeze

        def initialize(app, output: $stdout)
          super(app)
          @output = output
          @gems = []
          @selected = 0
          @detail = false
        end

        def activate
          @gems = discover_extensions
        end

        def discover_extensions
          Gem::Specification.select { |s| s.name.start_with?('lex-') }
                            .sort_by(&:name)
                            .map { |s| build_entry(s) }
        end

        def render(_width, height)
          lines = [Theme.c(:accent, '  LEX Extensions'), '']
          lines += if @detail && @gems[@selected]
                     detail_lines(@gems[@selected])
                   else
                     list_lines(height - 4)
                   end
          lines += ['', Theme.c(:muted, '  Enter=detail  o=open  q=back')]
          pad_lines(lines, height)
        end

        # rubocop:disable Metrics/MethodLength
        def handle_input(key)
          case key
          when :up
            @selected = [(@selected - 1), 0].max
            :handled
          when :down
            @selected = [(@selected + 1), @gems.size - 1].min
            :handled
          when :enter
            @detail = !@detail
            :handled
          when 'o'
            open_homepage
            :handled
          when 'q', :escape
            if @detail
              @detail = false
              :handled
            else
              :pop_screen
            end
          else
            :pass
          end
        end
        # rubocop:enable Metrics/MethodLength

        private

        def build_entry(spec)
          loaded = $LOADED_FEATURES.any? { |f| f.include?(spec.name.tr('-', '/')) }
          {
            name: spec.name,
            version: spec.version.to_s,
            summary: spec.summary,
            homepage: spec.homepage,
            loaded: loaded,
            category: categorize(spec.name),
            deps: spec.runtime_dependencies.map { |d| "#{d.name} #{d.requirement}" }
          }
        end

        def categorize(name)
          return 'Core' if CORE.include?(name)
          return 'AI' if AI.include?(name)
          return 'Service' if SERVICE.include?(name)
          return 'Agentic' if name.match?(/^lex-agentic-|^lex-theory-|^lex-mind-|^lex-planning|^lex-attention/)

          'Other'
        end

        # rubocop:disable Metrics/AbcSize
        def list_lines(max_height)
          grouped = @gems.group_by { |g| g[:category] }
          lines = []
          idx = 0
          grouped.each do |cat, gems|
            lines << Theme.c(:secondary, "  #{cat} (#{gems.size})")
            gems.each do |g|
              indicator = idx == @selected ? Theme.c(:accent, '>') : ' '
              status = g[:loaded] ? Theme.c(:success, 'loaded') : Theme.c(:muted, 'avail')
              lines << "  #{indicator} #{g[:name]} #{Theme.c(:muted, g[:version])} [#{status}]"
              idx += 1
            end
            lines << ''
          end
          lines.first(max_height)
        end

        # rubocop:enable Metrics/AbcSize

        def detail_lines(gem_entry)
          [
            "  #{Theme.c(:accent, gem_entry[:name])} #{gem_entry[:version]}",
            "  #{Theme.c(:muted, gem_entry[:category])}",
            '',
            "  #{gem_entry[:summary]}",
            '',
            "  #{Theme.c(:secondary, 'Dependencies:')}",
            *gem_entry[:deps].map { |d| "    #{d}" },
            '',
            "  #{Theme.c(:muted, gem_entry[:homepage] || 'no homepage')}"
          ]
        end

        def open_homepage
          entry = current_gem
          return unless entry && entry[:homepage]

          system_open(entry[:homepage])
        rescue StandardError
          nil
        end

        def system_open(url)
          case RUBY_PLATFORM
          when /darwin/ then system('open', url)
          when /linux/ then system('xdg-open', url)
          when /mingw|mswin/ then system('start', url)
          end
        end

        def current_gem
          return nil if @gems.empty?

          @gems[@selected]
        end

        def pad_lines(lines, height)
          lines + Array.new([height - lines.size, 0].max, '')
        end
      end
      # rubocop:enable Metrics/ClassLength
    end
  end
end
