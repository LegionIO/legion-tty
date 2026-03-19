# frozen_string_literal: true

module Legion
  module TTY
    module Components
      class ModelPicker
        def initialize(current_provider: nil, current_model: nil)
          @current_provider = current_provider
          @current_model = current_model
        end

        def available_models
          return [] unless defined?(Legion::LLM) && Legion::LLM.respond_to?(:settings)

          providers = Legion::LLM.settings[:providers]
          return [] unless providers.is_a?(Hash)

          models = []
          providers.each do |name, config|
            next unless config.is_a?(Hash) && config[:enabled]

            model = config[:default_model] || name.to_s
            current = (name.to_s == @current_provider.to_s)
            models << { provider: name.to_s, model: model, current: current }
          end
          models
        end

        def select_with_prompt(output: $stdout)
          models = available_models
          return nil if models.empty?

          require 'tty-prompt'
          prompt = ::TTY::Prompt.new(output: output)
          choices = models.map do |m|
            indicator = m[:current] ? ' (current)' : ''
            { name: "#{m[:provider]} / #{m[:model]}#{indicator}", value: m }
          end
          prompt.select('Select model:', choices, per_page: 10)
        rescue ::TTY::Reader::InputInterrupt, Interrupt
          nil
        end
      end
    end
  end
end
