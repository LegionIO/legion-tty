# frozen_string_literal: true

module Legion
  module TTY
    module Background
      class LlmProbe
        def initialize(logger: nil)
          @log = logger
        end

        def run_async(queue)
          Thread.new do
            result = probe_providers
            queue.push({ data: result })
          rescue StandardError => e
            @log&.log('llm_probe', "error: #{e.message}")
            queue.push({ data: { providers: [], error: e.message } })
          end
        end

        private

        def probe_providers
          require 'legion/llm'
          require 'legion/settings'

          begin
            Legion::LLM.start unless Legion::LLM.started?
          rescue StandardError => e
            @log&.log('llm_probe', "LLM start failed: #{e.message}")
          end

          results = []
          providers = Legion::LLM.settings[:providers] || {}

          providers.each do |name, config|
            next unless config[:enabled]

            result = ping_provider(name, config)
            results << result
            @log&.log('llm_probe', "#{name}: #{result[:status]} (#{result[:latency_ms]}ms)")
          end

          { providers: results }
        end

        def ping_provider(name, config)
          model = config[:default_model]
          start_time = Time.now
          RubyLLM.chat(model: model, provider: name).ask('Respond with only: pong')
          latency = ((Time.now - start_time) * 1000).round
          { name: name, model: model, status: :ok, latency_ms: latency }
        rescue StandardError => e
          latency = ((Time.now - start_time) * 1000).round
          { name: name, model: model, status: :error, latency_ms: latency, error: e.message }
        end
      end
    end
  end
end
