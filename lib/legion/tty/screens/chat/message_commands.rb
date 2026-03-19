# frozen_string_literal: true

module Legion
  module TTY
    module Screens
      class Chat < Base
        # rubocop:disable Metrics/ModuleLength
        module MessageCommands
          private

          # rubocop:disable Metrics/AbcSize
          def handle_compact(input)
            keep = (input.split(nil, 2)[1] || '5').to_i.clamp(1, 50)
            msgs = @message_stream.messages
            if msgs.size <= keep * 2
              @message_stream.add_message(role: :system, content: 'Conversation is already compact.')
              return :handled
            end

            system_msgs = msgs.select { |m| m[:role] == :system }
            recent = msgs.reject { |m| m[:role] == :system }.last(keep * 2)
            removed_count = msgs.size - system_msgs.size - recent.size
            @message_stream.messages.replace(system_msgs + recent)
            @message_stream.add_message(
              role: :system,
              content: "Compacted: removed #{removed_count} older messages, kept #{recent.size} recent."
            )
            :handled
          end
          # rubocop:enable Metrics/AbcSize

          def handle_copy(_input)
            last_assistant = @message_stream.messages.reverse.find { |m| m[:role] == :assistant }
            unless last_assistant
              @message_stream.add_message(role: :system, content: 'No assistant message to copy.')
              return :handled
            end

            content = last_assistant[:content].to_s
            copy_to_clipboard(content)
            @message_stream.add_message(
              role: :system,
              content: "Copied #{content.length} characters to clipboard."
            )
            :handled
          end

          def handle_diff(_input)
            if @loaded_message_count.nil?
              @message_stream.add_message(role: :system, content: 'No session was loaded. Nothing to diff against.')
              return :handled
            end

            new_count = @message_stream.messages.size - @loaded_message_count
            if new_count <= 0
              @message_stream.add_message(role: :system, content: 'No new messages since session was loaded.')
            else
              new_msgs = @message_stream.messages.last(new_count)
              lines = new_msgs.map { |m| "  + [#{m[:role]}] #{truncate_text(m[:content].to_s, 60)}" }
              @message_stream.add_message(
                role: :system,
                content: "#{new_count} new message(s) since load:\n#{lines.join("\n")}"
              )
            end
            :handled
          end

          def handle_search(input)
            query = input.split(nil, 2)[1]
            unless query
              @message_stream.add_message(role: :system, content: 'Usage: /search <text>')
              return :handled
            end

            results = search_messages(query)
            if results.empty?
              @message_stream.add_message(role: :system, content: "No messages matching '#{query}'.")
            else
              lines = results.map { |r| "  [#{r[:role]}] #{truncate_text(r[:content], 80)}" }
              @message_stream.add_message(
                role: :system,
                content: "Found #{results.size} message(s) matching '#{query}':\n#{lines.join("\n")}"
              )
            end
            :handled
          end

          def handle_grep(input)
            pattern_str = input.split(nil, 2)[1]
            unless pattern_str
              @message_stream.add_message(role: :system, content: 'Usage: /grep <regex>')
              return :handled
            end

            results = grep_messages(pattern_str)
            display_grep_results(results, pattern_str)
            :handled
          rescue RegexpError => e
            @message_stream.add_message(role: :system, content: "Invalid regex: #{e.message}")
            :handled
          end

          def grep_messages(pattern_str)
            regex = Regexp.new(pattern_str, Regexp::IGNORECASE)
            @message_stream.messages.select do |msg|
              msg[:content].is_a?(::String) && regex.match?(msg[:content])
            end
          end

          def display_grep_results(results, pattern_str)
            if results.empty?
              @message_stream.add_message(role: :system, content: "No messages matching /#{pattern_str}/.")
            else
              lines = results.map { |r| "  [#{r[:role]}] #{truncate_text(r[:content], 80)}" }
              @message_stream.add_message(
                role: :system,
                content: "Found #{results.size} message(s) matching /#{pattern_str}/:\n#{lines.join("\n")}"
              )
            end
          end

          def handle_undo
            msgs = @message_stream.messages
            last_user_idx = msgs.rindex { |m| m[:role] == :user }
            unless last_user_idx
              @message_stream.add_message(role: :system, content: 'Nothing to undo.')
              return :handled
            end

            msgs.slice!(last_user_idx..)
            :handled
          end

          def handle_pin(input)
            idx_str = input.split(nil, 2)[1]
            msg = if idx_str
                    @message_stream.messages[idx_str.to_i]
                  else
                    @message_stream.messages.reverse.find { |m| m[:role] == :assistant }
                  end
            unless msg
              @message_stream.add_message(role: :system, content: 'No message to pin.')
              return :handled
            end

            @pinned_messages << msg
            preview = truncate_text(msg[:content].to_s, 60)
            @message_stream.add_message(role: :system, content: "Pinned: #{preview}")
            :handled
          end

          def handle_pins
            if @pinned_messages.empty?
              @message_stream.add_message(role: :system, content: 'No pinned messages.')
            else
              lines = @pinned_messages.each_with_index.map do |msg, i|
                "  #{i + 1}. [#{msg[:role]}] #{truncate_text(msg[:content].to_s, 70)}"
              end
              @message_stream.add_message(role: :system,
                                          content: "Pinned messages (#{@pinned_messages.size}):\n#{lines.join("\n")}")
            end
            :handled
          end

          # rubocop:disable Metrics/AbcSize
          def handle_react(input)
            parts = input.split(nil, 3)
            if parts.size == 2
              emoji = parts[1]
              msg = @message_stream.messages.reverse.find { |m| m[:role] == :assistant }
            elsif parts.size >= 3 && parts[1].match?(/\A\d+\z/)
              idx = parts[1].to_i
              emoji = parts[2]
              msg = @message_stream.messages[idx]
            else
              @message_stream.add_message(role: :system, content: 'Usage: /react <emoji> or /react <N> <emoji>')
              return :handled
            end

            unless msg
              @message_stream.add_message(role: :system, content: 'No message to react to.')
              return :handled
            end

            msg[:reactions] ||= []
            msg[:reactions] << emoji
            @message_stream.add_message(role: :system, content: "Reaction #{emoji} added.")
            :handled
          end
          # rubocop:enable Metrics/AbcSize

          # rubocop:disable Metrics/AbcSize
          def handle_tag(input)
            parts = input.split(nil, 3)
            if parts.size == 2
              label = parts[1]
              msg = @message_stream.messages.reverse.find { |m| m[:role] == :assistant }
            elsif parts.size >= 3 && parts[1].match?(/\A\d+\z/)
              idx = parts[1].to_i
              label = parts[2]
              msg = @message_stream.messages[idx]
            else
              @message_stream.add_message(role: :system, content: 'Usage: /tag <label> or /tag <N> <label>')
              return :handled
            end

            unless msg
              @message_stream.add_message(role: :system, content: 'No message to tag.')
              return :handled
            end

            msg[:tags] ||= []
            msg[:tags] |= [label]
            @message_stream.add_message(role: :system, content: "Tag '#{label}' added.")
            :handled
          end
          # rubocop:enable Metrics/AbcSize

          def handle_tags(input)
            label = input.split(nil, 2)[1]
            if label
              filter_messages_by_tag(label)
            else
              show_all_tags
            end
            :handled
          end

          def handle_count(input)
            query = input.split(nil, 2)[1]
            unless query
              @message_stream.add_message(role: :system, content: 'Usage: /count <pattern>')
              return :handled
            end

            results = search_messages(query)
            if results.empty?
              @message_stream.add_message(role: :system, content: "0 messages matching '#{query}'.")
            else
              breakdown = results.group_by { |m| m[:role] }
                                 .map { |role, msgs| "#{role}: #{msgs.size}" }
                                 .join(', ')
              @message_stream.add_message(
                role: :system,
                content: "#{results.size} message(s) matching '#{query}' (#{breakdown})."
              )
            end
            :handled
          end

          def search_messages(query)
            pattern = query.downcase
            @message_stream.messages.select do |msg|
              msg[:content].is_a?(::String) && msg[:content].downcase.include?(pattern)
            end
          end

          def truncate_text(text, max_length)
            return text if text.length <= max_length

            "#{text[0...max_length]}..."
          end

          def copy_to_clipboard(text)
            IO.popen('pbcopy', 'w') { |io| io.write(text) }
          rescue Errno::ENOENT
            begin
              IO.popen('xclip -selection clipboard', 'w') { |io| io.write(text) }
            rescue Errno::ENOENT
              nil
            end
          end

          # rubocop:disable Metrics/AbcSize
          def show_all_tags
            tagged = @message_stream.messages.select { |m| m[:tags]&.any? }
            if tagged.empty?
              @message_stream.add_message(role: :system, content: 'No tagged messages.')
              return
            end

            counts = Hash.new(0)
            tagged.each { |m| m[:tags].each { |t| counts[t] += 1 } }
            lines = counts.sort.map { |tag, count| "  ##{tag} (#{count})" }
            @message_stream.add_message(role: :system, content: "Tags:\n#{lines.join("\n")}")
          end
          # rubocop:enable Metrics/AbcSize

          def filter_messages_by_tag(label)
            results = @message_stream.messages.select { |m| m[:tags]&.include?(label) }
            if results.empty?
              @message_stream.add_message(role: :system, content: "No messages tagged '##{label}'.")
            else
              lines = results.map { |r| "  [#{r[:role]}] #{truncate_text(r[:content].to_s, 80)}" }
              @message_stream.add_message(
                role: :system,
                content: "Messages tagged '##{label}' (#{results.size}):\n#{lines.join("\n")}"
              )
            end
          end

          def handle_sort(input)
            arg = input.split(nil, 2)[1]
            if arg == 'role'
              sort_by_role
            else
              sort_by_length
            end
            :handled
          end

          def sort_by_length
            msgs = @message_stream.messages
            if msgs.empty?
              @message_stream.add_message(role: :system, content: 'No messages to sort.')
              return
            end

            sorted = msgs.sort_by { |m| -m[:content].to_s.length }.first(10)
            lines = sorted.map { |m| format_length_line(m) }
            @message_stream.add_message(
              role: :system,
              content: "Messages by length (top #{sorted.size}):\n#{lines.join("\n")}"
            )
          end

          def format_length_line(msg)
            len = msg[:content].to_s.length
            preview = truncate_text(msg[:content].to_s, 60)
            "  [#{msg[:role]}] (#{len} chars) #{preview}"
          end

          def sort_by_role
            msgs = @message_stream.messages
            if msgs.empty?
              @message_stream.add_message(role: :system, content: 'No messages to sort.')
              return
            end

            counts = msgs.group_by { |m| m[:role] }
                         .transform_values(&:size)
                         .sort_by { |_, count| -count }
            lines = counts.map { |role, count| "  #{role}: #{count}" }
            @message_stream.add_message(
              role: :system,
              content: "Messages by role:\n#{lines.join("\n")}"
            )
          end

          def favorites_file
            File.expand_path('~/.legionio/favorites.json')
          end

          def load_favorites
            return [] unless File.exist?(favorites_file)

            raw = File.read(favorites_file)
            parsed = ::JSON.parse(raw, symbolize_names: true)
            parsed.is_a?(Array) ? parsed : []
          rescue StandardError
            []
          end

          def save_favorites(favs)
            require 'fileutils'
            FileUtils.mkdir_p(File.dirname(favorites_file))
            File.write(favorites_file, ::JSON.generate(favs))
          end

          # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
          def handle_fav(input)
            idx_str = input.split(nil, 2)[1]
            msg = if idx_str
                    @message_stream.messages[idx_str.to_i]
                  else
                    @message_stream.messages.reverse.find { |m| m[:role] == :assistant }
                  end
            unless msg
              @message_stream.add_message(role: :system, content: 'No message to favorite.')
              return :handled
            end

            @favorites ||= []
            entry = {
              role: msg[:role],
              content: msg[:content].to_s,
              saved_at: Time.now.iso8601,
              session: @session_name
            }
            @favorites << entry
            save_favorites(load_favorites + [entry])
            preview = truncate_text(msg[:content].to_s, 60)
            @message_stream.add_message(role: :system, content: "Favorited: #{preview}")
            :handled
          end
          # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

          def handle_favs
            all_favs = load_favorites
            if all_favs.empty?
              @message_stream.add_message(role: :system, content: 'No favorites saved.')
              return :handled
            end

            lines = all_favs.each_with_index.map do |fav, i|
              saved = fav[:saved_at] || ''
              "  #{i + 1}. [#{fav[:role]}] #{truncate_text(fav[:content].to_s, 60)} (#{saved})"
            end
            @message_stream.add_message(
              role: :system,
              content: "Favorites (#{all_favs.size}):\n#{lines.join("\n")}"
            )
            :handled
          end
        end
        # rubocop:enable Metrics/ModuleLength
      end
    end
  end
end
