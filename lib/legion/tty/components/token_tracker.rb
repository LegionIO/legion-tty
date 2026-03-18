# frozen_string_literal: true

module Legion
  module TTY
    module Components
      class TokenTracker
        PRICING = {
          'claude' => { input: 0.003, output: 0.015 },
          'openai' => { input: 0.005, output: 0.015 },
          'gemini' => { input: 0.001, output: 0.002 },
          'azure' => { input: 0.005, output: 0.015 },
          'local' => { input: 0.0, output: 0.0 }
        }.freeze

        attr_reader :total_input_tokens, :total_output_tokens, :total_cost

        def initialize(provider: 'claude')
          @provider = provider
          @total_input_tokens = 0
          @total_output_tokens = 0
          @total_cost = 0.0
        end

        def track(input_tokens:, output_tokens:)
          @total_input_tokens += input_tokens.to_i
          @total_output_tokens += output_tokens.to_i
          rates = PRICING[@provider] || PRICING['claude']
          @total_cost += (input_tokens.to_i * rates[:input] / 1000.0) + (output_tokens.to_i * rates[:output] / 1000.0)
        end

        def summary
          input = format_number(@total_input_tokens)
          output = format_number(@total_output_tokens)
          cost = format('%.4f', @total_cost)
          "Tokens: #{input} in / #{output} out | Cost: $#{cost}"
        end

        private

        def format_number(num)
          num.to_s.chars.reverse.each_slice(3).map(&:join).join(',').reverse
        end
      end
    end
  end
end
