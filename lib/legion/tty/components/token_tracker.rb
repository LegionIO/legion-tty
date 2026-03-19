# frozen_string_literal: true

module Legion
  module TTY
    module Components
      class TokenTracker
        # Rates per 1k tokens (input/output) — current as of 2026-03
        MODEL_PRICING = {
          'claude-opus-4-6' => { input: 0.015, output: 0.075 },
          'claude-sonnet-4-6' => { input: 0.003, output: 0.015 },
          'claude-haiku-4-5' => { input: 0.0008, output: 0.004 },
          'gpt-4o' => { input: 0.0025, output: 0.010 },
          'gpt-4o-mini' => { input: 0.00015, output: 0.0006 },
          'gpt-4.1' => { input: 0.002, output: 0.008 },
          'gemini-2.0-flash' => { input: 0.0001, output: 0.0004 },
          'gemini-2.5-pro' => { input: 0.00125, output: 0.01 },
          'local' => { input: 0.0, output: 0.0 }
        }.freeze

        PROVIDER_PRICING = {
          'anthropic' => { input: 0.003, output: 0.015 },
          'claude' => { input: 0.003, output: 0.015 },
          'openai' => { input: 0.0025, output: 0.010 },
          'gemini' => { input: 0.0001, output: 0.0004 },
          'bedrock' => { input: 0.003, output: 0.015 },
          'azure' => { input: 0.0025, output: 0.010 },
          'ollama' => { input: 0.0, output: 0.0 },
          'local' => { input: 0.0, output: 0.0 }
        }.freeze

        attr_reader :total_input_tokens, :total_output_tokens, :total_cost

        def initialize(provider: 'claude', model: nil)
          @provider = provider
          @model = model
          @total_input_tokens = 0
          @total_output_tokens = 0
          @total_cost = 0.0
        end

        def update_model(model)
          @model = model
        end

        def track(input_tokens:, output_tokens:, model: nil)
          @model = model if model
          @total_input_tokens += input_tokens.to_i
          @total_output_tokens += output_tokens.to_i
          rates = rates_for(@model, @provider)
          @total_cost += (input_tokens.to_i * rates[:input] / 1000.0) +
                         (output_tokens.to_i * rates[:output] / 1000.0)
        end

        def summary
          input = format_number(@total_input_tokens)
          output = format_number(@total_output_tokens)
          cost = format('%.4f', @total_cost)
          "Tokens: #{input} in / #{output} out | Cost: $#{cost}"
        end

        private

        def rates_for(model, provider)
          return MODEL_PRICING[model] if model && MODEL_PRICING.key?(model)

          MODEL_PRICING.each do |key, rates|
            return rates if model&.include?(key)
          end

          PROVIDER_PRICING[provider] || PROVIDER_PRICING['claude']
        end

        def format_number(num)
          num.to_s.chars.reverse.each_slice(3).map(&:join).join(',').reverse
        end
      end
    end
  end
end
