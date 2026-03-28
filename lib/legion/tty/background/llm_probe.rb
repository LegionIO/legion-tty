# frozen_string_literal: true

module Legion
  module TTY
    module Background
      class LlmProbe
        def initialize(logger: nil, wait_queue: nil)
          @log = logger
          @wait_queue = wait_queue
        end

        def run_async(queue)
          Thread.new do
            wait_for_bootstrap if @wait_queue
            result = probe_providers
            queue.push({ data: result })
          rescue StandardError => e
            @log&.log('llm_probe', "error: #{e.message}")
            queue.push({ data: { providers: [], error: e.message } })
          end
        end

        private

        def wait_for_bootstrap
          deadline = Time.now + 15
          loop do
            return unless @wait_queue.empty?
            return if Time.now >= deadline

            sleep 0.2
          end
          @log&.log('llm_probe', 'bootstrap wait complete')
        rescue StandardError => e
          @log&.log('llm_probe', "bootstrap wait error: #{e.message}")
        end

        def probe_providers
          require 'legion/llm'
          require 'legion/settings'
          start_llm
          results = collect_provider_results
          { providers: results }
        end

        def start_llm
          Legion::LLM.start unless Legion::LLM.started?
        rescue StandardError => e
          @log&.log('llm_probe', "LLM start failed: #{e.message}")
        end

        def collect_provider_results
          providers = Legion::LLM.settings[:providers] || {}
          providers.filter_map do |name, config|
            next unless config[:enabled]

            result = ping_provider(name, config)
            @log&.log('llm_probe', "#{name}: #{result[:status]} (#{result[:latency_ms]}ms)")
            result
          end
        end

        def ping_provider(name, config)
          model = config[:default_model]
          start_time = Time.now
          RubyLLM.chat(model: model, provider: name).ask('Respond with only: pong')
          latency = ((Time.now - start_time) * 1000).round
          { name: name, model: model, status: :ok, latency_ms: latency }
        rescue StandardError => e
          latency = ((Time.now - start_time) * 1000).round
          Legion::Logging.debug("ping_provider #{name} failed: #{e.message}") if defined?(Legion::Logging)
          { name: name, model: model, status: :configured, latency_ms: latency, error: e.message }
        end
      end
    end
  end
end
