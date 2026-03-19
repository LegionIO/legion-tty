# frozen_string_literal: true

module Legion
  module TTY
    module Screens
      class Chat < Base
        module ExportCommands
          private

          def handle_export(input)
            require 'fileutils'
            path = build_export_path(input)
            dispatch_export(path, input.split[1]&.downcase)
            @status_bar.notify(message: 'Exported', level: :success, ttl: 3)
            @message_stream.add_message(role: :system, content: "Exported to: #{path}")
            :handled
          rescue StandardError => e
            @message_stream.add_message(role: :system, content: "Export failed: #{e.message}")
            :handled
          end

          def build_export_path(input)
            format = input.split[1]&.downcase
            format = 'md' unless %w[json md html yaml].include?(format)
            exports_dir = File.expand_path('~/.legionio/exports')
            FileUtils.mkdir_p(exports_dir)
            timestamp = Time.now.strftime('%Y%m%d-%H%M%S')
            ext = { 'json' => 'json', 'md' => 'md', 'html' => 'html', 'yaml' => 'yaml' }[format]
            File.join(exports_dir, "chat-#{timestamp}.#{ext}")
          end

          def dispatch_export(path, format)
            case format
            when 'json'
              export_json(path)
            when 'html'
              export_html(path)
            when 'yaml'
              export_yaml(path)
            else
              export_markdown(path)
            end
          end

          def export_markdown(path)
            lines = ["# Chat Export\n", "_Exported: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}_\n\n---\n"]
            @message_stream.messages.each do |msg|
              role_label = msg[:role].to_s.capitalize
              lines << "\n**#{role_label}**\n\n#{msg[:content]}\n"
            end
            File.write(path, lines.join)
          end

          def export_json(path)
            require 'json'
            data = {
              exported_at: Time.now.iso8601,
              token_summary: @token_tracker.summary,
              messages: @message_stream.messages.map { |m| { role: m[:role].to_s, content: m[:content] } }
            }
            File.write(path, ::JSON.pretty_generate(data))
          end

          def export_yaml(path)
            require 'yaml'
            data = {
              'exported_at' => Time.now.iso8601,
              'messages' => @message_stream.messages.map do |m|
                { 'role' => m[:role].to_s, 'content' => m[:content], 'timestamp' => m[:timestamp]&.iso8601 }
              end
            }
            File.write(path, ::YAML.dump(data))
          end

          # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
          def export_html(path)
            lines = [
              '<!DOCTYPE html><html><head>',
              '<meta charset="utf-8">',
              '<title>Chat Export</title>',
              '<style>',
              'body { font-family: system-ui; max-width: 800px; margin: 0 auto; ' \
              'padding: 20px; background: #1e1b2e; color: #d0cce6; }',
              '.msg { margin: 12px 0; padding: 8px 12px; border-radius: 8px; }',
              '.user { background: #2a2640; }',
              '.assistant { background: #1a1730; }',
              '.system { background: #25223a; color: #8b85a8; font-style: italic; }',
              '.role { font-weight: bold; color: #9d91e6; font-size: 0.85em; }',
              '</style></head><body>',
              '<h1>Chat Export</h1>',
              "<p>Exported: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}</p>"
            ]
            @message_stream.messages.each do |msg|
              role = msg[:role].to_s
              content = escape_html(msg[:content].to_s).gsub("\n", '<br>')
              lines << "<div class='msg #{role}'>"
              lines << "<span class='role'>#{role.capitalize}</span>"
              lines << "<p>#{content}</p>"
              lines << '</div>'
            end
            lines << '</body></html>'
            File.write(path, lines.join("\n"))
          end
          # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

          def escape_html(text)
            text.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;').gsub('"', '&quot;')
          end

          # rubocop:disable Metrics/AbcSize
          def handle_bookmark
            require 'fileutils'
            if @pinned_messages.empty?
              @message_stream.add_message(role: :system, content: 'No pinned messages to export.')
              return :handled
            end

            exports_dir = File.expand_path('~/.legionio/exports')
            FileUtils.mkdir_p(exports_dir)
            timestamp = Time.now.strftime('%Y%m%d-%H%M%S')
            path = File.join(exports_dir, "bookmarks-#{timestamp}.md")
            lines = ["# Pinned Messages\n", "_Exported: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}_\n\n---\n"]
            @pinned_messages.each_with_index do |msg, i|
              role_label = msg[:role].to_s.capitalize
              lines << "\n## Bookmark #{i + 1} (#{role_label})\n\n#{msg[:content]}\n"
            end
            File.write(path, lines.join)
            @message_stream.add_message(role: :system, content: "Bookmarks exported to: #{path}")
            :handled
          rescue StandardError => e
            @message_stream.add_message(role: :system, content: "Bookmark export failed: #{e.message}")
            :handled
          end
          # rubocop:enable Metrics/AbcSize

          def handle_tee(input)
            arg = input.split(nil, 2)[1]
            if arg.nil?
              status = @tee_path ? "Tee active: #{@tee_path}" : 'Tee inactive.'
              @message_stream.add_message(role: :system, content: status)
              return :handled
            end

            if arg.strip == 'off'
              @tee_path = nil
              @message_stream.add_message(role: :system, content: 'Tee stopped.')
            else
              @tee_path = File.expand_path(arg.strip)
              @message_stream.add_message(role: :system, content: "Tee started: #{@tee_path}")
            end
            :handled
          rescue StandardError => e
            @message_stream.add_message(role: :system, content: "Tee error: #{e.message}")
            :handled
          end

          def tee_message(line)
            return unless @tee_path

            File.open(@tee_path, 'a') { |f| f.puts(line) }
          rescue StandardError
            nil
          end
        end
      end
    end
  end
end
