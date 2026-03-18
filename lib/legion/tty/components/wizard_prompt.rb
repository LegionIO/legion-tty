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
          'Local (Ollama/LM Studio)' => 'local'
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

        # rubocop:disable Naming/PredicateMethod
        def confirm(question)
          @prompt.yes?(question)
        end
        # rubocop:enable Naming/PredicateMethod

        def select_from(question, choices)
          @prompt.select(question, choices)
        end
      end
    end
  end
end
