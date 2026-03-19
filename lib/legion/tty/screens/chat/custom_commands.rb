# frozen_string_literal: true

module Legion
  module TTY
    module Screens
      class Chat < Base
        # rubocop:disable Metrics/ModuleLength
        module CustomCommands
          private

          def handle_alias(input)
            parts = input.split(nil, 3)
            if parts.size < 2
              if @aliases.empty?
                @message_stream.add_message(role: :system, content: 'No aliases defined.')
              else
                lines = @aliases.map { |k, v| "  #{k} => #{v}" }
                @message_stream.add_message(role: :system, content: "Aliases:\n#{lines.join("\n")}")
              end
              return :handled
            end

            shortname = parts[1]
            expansion = parts[2]
            unless expansion
              @message_stream.add_message(role: :system, content: 'Usage: /alias <shortname> <command and args>')
              return :handled
            end

            alias_key = shortname.start_with?('/') ? shortname : "/#{shortname}"
            @aliases[alias_key] = expansion
            @message_stream.add_message(role: :system, content: "Alias created: #{alias_key} => #{expansion}")
            :handled
          end

          def handle_snippet(input)
            parts = input.split(nil, 3)
            subcommand = parts[1]
            name = parts[2]

            case subcommand
            when 'save'
              snippet_save(name)
            when 'load'
              snippet_load(name)
            when 'list'
              snippet_list
            when 'delete'
              snippet_delete(name)
            else
              @message_stream.add_message(
                role: :system,
                content: 'Usage: /snippet save|load|list|delete <name>'
              )
            end
            :handled
          end

          def snippet_dir
            File.expand_path('~/.legionio/snippets')
          end

          # rubocop:disable Metrics/AbcSize
          def snippet_save(name)
            unless name
              @message_stream.add_message(role: :system, content: 'Usage: /snippet save <name>')
              return
            end

            last_assistant = @message_stream.messages.reverse.find { |m| m[:role] == :assistant }
            unless last_assistant
              @message_stream.add_message(role: :system, content: 'No assistant message to save as snippet.')
              return
            end

            require 'fileutils'
            FileUtils.mkdir_p(snippet_dir)
            path = File.join(snippet_dir, "#{name}.txt")
            File.write(path, last_assistant[:content].to_s)
            @snippets[name] = last_assistant[:content].to_s
            @message_stream.add_message(role: :system, content: "Snippet '#{name}' saved.")
          end
          # rubocop:enable Metrics/AbcSize

          def snippet_load(name)
            unless name
              @message_stream.add_message(role: :system, content: 'Usage: /snippet load <name>')
              return
            end

            content = @snippets[name]
            if content.nil?
              path = File.join(snippet_dir, "#{name}.txt")
              content = File.read(path) if File.exist?(path)
            end

            unless content
              @message_stream.add_message(role: :system, content: "Snippet '#{name}' not found.")
              return
            end

            @snippets[name] = content
            @message_stream.add_message(role: :user, content: content)
            @message_stream.add_message(role: :system, content: "Snippet '#{name}' inserted.")
          end

          # rubocop:disable Metrics/AbcSize
          def snippet_list
            disk_snippets = Dir.glob(File.join(snippet_dir, '*.txt')).map { |f| File.basename(f, '.txt') }
            all_names = (@snippets.keys + disk_snippets).uniq.sort

            if all_names.empty?
              @message_stream.add_message(role: :system, content: 'No snippets saved.')
              return
            end

            lines = all_names.map do |sname|
              content = @snippets[sname] || begin
                path = File.join(snippet_dir, "#{sname}.txt")
                File.exist?(path) ? File.read(path) : ''
              end
              "  #{sname}: #{truncate_text(content.to_s, 60)}"
            end
            @message_stream.add_message(role: :system, content: "Snippets (#{all_names.size}):\n#{lines.join("\n")}")
          end
          # rubocop:enable Metrics/AbcSize

          def snippet_delete(name)
            unless name
              @message_stream.add_message(role: :system, content: 'Usage: /snippet delete <name>')
              return
            end

            @snippets.delete(name)
            path = File.join(snippet_dir, "#{name}.txt")
            if File.exist?(path)
              File.delete(path)
              @message_stream.add_message(role: :system, content: "Snippet '#{name}' deleted.")
            else
              @message_stream.add_message(role: :system, content: "Snippet '#{name}' not found.")
            end
          end
        end
        # rubocop:enable Metrics/ModuleLength
      end
    end
  end
end
