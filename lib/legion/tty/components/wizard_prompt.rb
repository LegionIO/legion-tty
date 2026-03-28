# frozen_string_literal: true

require 'tty-prompt'

module Legion
  module TTY
    module Components
      class WizardPrompt
        PROVIDERS = {
          'Claude (Anthropic)' => 'claude',
          'OpenAI' => 'openai',
          'Gemini (Google)' => 'gemini',
          'Azure OpenAI' => 'azure',
          'AWS Bedrock' => 'bedrock',
          'Local (Ollama/LM Studio)' => 'local',
          'Skip for now' => nil
        }.freeze

        def initialize(prompt: nil)
          @prompt = prompt || ::TTY::Prompt.new
        end

        def ask_name
          @prompt.ask('What should I call you?', required: true) { |q| q.modify(:strip) }
        end

        def ask_name_with_default(default)
          @prompt.ask('What should I call you?', default: default) { |q| q.modify(:strip) }
        end

        def select_provider
          @prompt.select('Choose an AI provider:', PROVIDERS)
        end

        def ask_api_key(provider:)
          @prompt.mask("Enter API key for #{provider}:")
        end

        def ask_secret(question)
          @prompt.mask(question)
        end

        def ask_with_default(question, default)
          @prompt.ask(question, default: default)
        end

        # rubocop:disable Naming/PredicateMethod
        def confirm(question)
          @prompt.yes?(question)
        end
        # rubocop:enable Naming/PredicateMethod

        def select_from(question, choices)
          @prompt.select(question, choices)
        end

        def display_provider_results(providers)
          providers.each do |p|
            icon = case p[:status]
                   when :ok then "\u2705"
                   when :configured then "\U0001F511"
                   else "\u274C"
                   end
            latency = "#{p[:latency_ms]}ms"
            label = "#{icon} #{p[:name]} (#{p[:model]}) \u2014 #{latency}"
            label += p[:status] == :configured ? ' [configured, not validated]' : " [#{p[:error]}]" if p[:error]
            @prompt.say(label)
          end
        end

        def select_default_provider(working_providers)
          return nil if working_providers.empty?
          return working_providers.first[:name] if working_providers.size == 1

          choices = working_providers.map do |p|
            { name: "#{p[:name]} (#{p[:model]}, #{p[:latency_ms]}ms)", value: p[:name] }
          end
          choices << { name: 'Skip for now', value: nil }
          @prompt.select('Multiple providers available. Choose your default:', choices)
        end
      end
    end
  end
end
