# frozen_string_literal: true

module Legion
  module TTY
    module Screens
      class Chat < Base
        module ModelCommands
          private

          def handle_model(input)
            name = input.split(nil, 2)[1]
            if name
              switch_model(name)
            else
              show_current_model
            end
            :handled
          end

          def switch_model(name)
            unless @llm_chat
              @message_stream.add_message(role: :system, content: 'No active LLM session.')
              return
            end

            apply_model_switch(name)
          rescue StandardError => e
            @message_stream.add_message(role: :system, content: "Failed to switch model: #{e.message}")
          end

          def apply_model_switch(name)
            new_chat = try_provider_switch(name)
            if new_chat
              @llm_chat = new_chat
              @status_bar.update(model: name)
              @token_tracker.update_model(name)
              @message_stream.add_message(role: :system, content: "Switched to provider: #{name}")
            elsif @llm_chat.respond_to?(:with_model)
              @llm_chat.with_model(name)
              @status_bar.update(model: name)
              @token_tracker.update_model(name)
              @message_stream.add_message(role: :system, content: "Model switched to: #{name}")
            else
              @status_bar.update(model: name)
              @message_stream.add_message(role: :system, content: "Model set to: #{name}")
            end
          end

          def try_provider_switch(name)
            return nil unless defined?(Legion::LLM)

            providers = Legion::LLM.settings[:providers]
            return nil unless providers.is_a?(Hash) && providers.key?(name.to_sym)

            Legion::LLM.chat(provider: name)
          rescue StandardError
            nil
          end

          def open_model_picker
            require_relative '../components/model_picker'
            picker = Components::ModelPicker.new(
              current_provider: safe_config[:provider],
              current_model: @llm_chat.respond_to?(:model) ? @llm_chat.model.to_s : nil
            )
            selection = picker.select_with_prompt(output: @output)
            return unless selection

            switch_model(selection[:provider])
          end

          def show_current_model
            model = @llm_chat.respond_to?(:model) ? @llm_chat.model : nil
            provider = safe_config[:provider] || 'unknown'
            info = model ? "#{model} (#{provider})" : provider
            @message_stream.add_message(role: :system, content: "Current model: #{info}")
          end

          def handle_system(input)
            text = input.split(nil, 2)[1]
            if text
              if @llm_chat.respond_to?(:with_instructions)
                @llm_chat.with_instructions(text)
                @message_stream.add_message(role: :system, content: 'System prompt updated.')
              else
                @message_stream.add_message(role: :system, content: 'No active LLM session.')
              end
            else
              @message_stream.add_message(role: :system, content: 'Usage: /system <prompt text>')
            end
            :handled
          end

          def handle_personality(input)
            name = input.split(nil, 2)[1]
            if name && PERSONALITIES.key?(name)
              apply_personality(name)
            elsif name
              available = PERSONALITIES.keys.join(', ')
              @message_stream.add_message(role: :system,
                                          content: "Unknown personality '#{name}'. Available: #{available}")
            else
              current = @personality || 'default'
              available = PERSONALITIES.keys.join(', ')
              @message_stream.add_message(role: :system, content: "Current: #{current}\nAvailable: #{available}")
            end
            :handled
          end

          def apply_personality(name)
            @personality = name
            if @llm_chat.respond_to?(:with_instructions)
              @llm_chat.with_instructions(PERSONALITIES[name])
              @message_stream.add_message(role: :system, content: "Personality switched to: #{name}")
            else
              @message_stream.add_message(role: :system, content: "Personality set to: #{name} (no active LLM)")
            end
          end

          def handle_retry
            unless @last_user_input
              @message_stream.add_message(role: :system, content: 'Nothing to retry.')
              return :handled
            end

            msgs = @message_stream.messages
            last_assistant_idx = msgs.rindex { |m| m[:role] == :assistant }
            msgs.delete_at(last_assistant_idx) if last_assistant_idx

            @status_bar.notify(message: 'Retrying...', level: :info, ttl: 2)
            @message_stream.add_message(role: :assistant, content: '')
            send_to_llm(@last_user_input)
            :handled
          end

          def handle_speak(input)
            unless RUBY_PLATFORM =~ /darwin/
              @message_stream.add_message(role: :system, content: 'Text-to-speech is only available on macOS.')
              return :handled
            end

            arg = input.split(nil, 2)[1]&.strip&.downcase
            case arg
            when 'on'
              @speak_mode = true
              @message_stream.add_message(role: :system, content: 'Text-to-speech ON.')
            when 'off'
              @speak_mode = false
              @message_stream.add_message(role: :system, content: 'Text-to-speech OFF.')
            else
              @speak_mode = !@speak_mode
              state = @speak_mode ? 'ON' : 'OFF'
              @message_stream.add_message(role: :system, content: "Text-to-speech #{state}.")
            end
            :handled
          end
        end
      end
    end
  end
end
