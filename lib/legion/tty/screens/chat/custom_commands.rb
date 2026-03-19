# frozen_string_literal: true

module Legion
  module TTY
    module Screens
      class Chat < Base
        # rubocop:disable Metrics/ModuleLength
        module CustomCommands
          TEMPLATES = {
            'explain' => 'Explain the following concept in simple terms: ',
            'review' => "Review this code for bugs, security issues, and improvements:\n```\n",
            'summarize' => "Summarize the following text in 3 bullet points:\n",
            'refactor' => "Refactor this code for readability and performance:\n```\n",
            'test' => "Write unit tests for this code:\n```\n",
            'debug' => "Help me debug this error:\n",
            'translate' => 'Translate the following to ',
            'compare' => "Compare and contrast the following:\n"
          }.freeze

          private

          # rubocop:disable Metrics/MethodLength
          def handle_template(input)
            name = input.split(nil, 2)[1]
            unless name
              lines = TEMPLATES.map { |k, v| "  #{k}: #{v[0, 60]}" }
              @message_stream.add_message(
                role: :system,
                content: "Available templates (#{TEMPLATES.size}):\n#{lines.join("\n")}\n\nUsage: /template <name>"
              )
              return :handled
            end

            template = TEMPLATES[name]
            unless template
              available = TEMPLATES.keys.join(', ')
              @message_stream.add_message(
                role: :system,
                content: "Template '#{name}' not found. Available: #{available}"
              )
              return :handled
            end

            @message_stream.add_message(
              role: :system,
              content: "Template '#{name}':\n#{template}"
            )
            :handled
          end
          # rubocop:enable Metrics/MethodLength

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

          # rubocop:disable Metrics/MethodLength
          def handle_macro(input)
            parts = input.split(nil, 3)
            subcommand = parts[1]
            name = parts[2]

            case subcommand
            when 'record'
              macro_record(name)
            when 'stop'
              macro_stop
            when 'play'
              macro_play(name)
            when 'list'
              macro_list
            when 'delete'
              macro_delete(name)
            else
              @message_stream.add_message(
                role: :system,
                content: 'Usage: /macro record|stop|play|list|delete <name>'
              )
            end
            :handled
          end
          # rubocop:enable Metrics/MethodLength

          def macro_record(name)
            unless name
              @message_stream.add_message(role: :system, content: 'Usage: /macro record <name>')
              return
            end

            @recording_macro = name
            @macro_buffer = []
            @message_stream.add_message(role: :system,
                                        content: "Recording macro '#{name}'... Use /macro stop to finish.")
          end

          def macro_stop
            unless @recording_macro
              @message_stream.add_message(role: :system, content: 'No macro recording in progress.')
              return
            end

            name = @recording_macro
            @macros[name] = @macro_buffer.dup
            @recording_macro = nil
            @macro_buffer = []
            @message_stream.add_message(role: :system,
                                        content: "Macro '#{name}' saved (#{@macros[name].size} commands).")
          end

          def macro_play(name)
            unless name
              @message_stream.add_message(role: :system, content: 'Usage: /macro play <name>')
              return
            end

            commands = @macros[name]
            unless commands
              @message_stream.add_message(role: :system, content: "Macro '#{name}' not found.")
              return
            end

            @message_stream.add_message(role: :system,
                                        content: "Playing macro '#{name}' (#{commands.size} commands)...")
            commands.each { |cmd| handle_slash_command(cmd) }
          end

          def macro_list
            if @macros.empty?
              @message_stream.add_message(role: :system, content: 'No macros defined.')
              return
            end

            lines = @macros.map do |n, cmds|
              preview = cmds.first(3).join(', ')
              preview += ', ...' if cmds.size > 3
              "  #{n} (#{cmds.size}): #{preview}"
            end
            status = @recording_macro ? " [recording: #{@recording_macro}]" : ''
            @message_stream.add_message(role: :system,
                                        content: "Macros (#{@macros.size})#{status}:\n#{lines.join("\n")}")
          end

          def macro_delete(name)
            unless name
              @message_stream.add_message(role: :system, content: 'Usage: /macro delete <name>')
              return
            end

            if @macros.delete(name)
              @message_stream.add_message(role: :system, content: "Macro '#{name}' deleted.")
            else
              @message_stream.add_message(role: :system, content: "Macro '#{name}' not found.")
            end
          end

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
