# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'fileutils'
require 'legion/json'

module Legion
  module TTY
    module DaemonClient
      SUCCESS_CODES = [200, 201, 202].freeze

      class << self
        def configure(daemon_url: 'http://127.0.0.1:4567', cache_file: nil, timeout: 5)
          @daemon_url = daemon_url
          @cache_file = cache_file || File.expand_path('~/.legionio/catalog.json')
          @timeout = timeout
          @manifest = nil
        end

        def available?
          uri = URI("#{daemon_url}/api/health")
          response = Net::HTTP.start(uri.hostname, uri.port, open_timeout: @timeout, read_timeout: @timeout) do |http|
            http.get(uri.path)
          end
          response.code.to_i == 200
        rescue StandardError => e
          Legion::Logging.debug("daemon available? check failed: #{e.message}") if defined?(Legion::Logging)
          false
        end

        def fetch_manifest
          uri = URI("#{daemon_url}/api/catalog")
          response = Net::HTTP.start(uri.hostname, uri.port, open_timeout: @timeout, read_timeout: @timeout) do |http|
            http.get(uri.path)
          end
          return nil unless response.code.to_i == 200

          body = Legion::JSON.load(response.body)
          @manifest = body[:data]
          write_cache(@manifest)
          @manifest
        rescue StandardError => e
          Legion::Logging.warn("fetch_manifest failed: #{e.message}") if defined?(Legion::Logging)
          nil
        end

        def cached_manifest
          return @manifest if @manifest

          return nil unless @cache_file && File.exist?(@cache_file)

          @manifest = Legion::JSON.load(File.read(@cache_file))
        rescue StandardError => e
          Legion::Logging.warn("cached_manifest failed: #{e.message}") if defined?(Legion::Logging)
          nil
        end

        def manifest
          @manifest || cached_manifest
        end

        def match_intent(intent_text)
          return nil unless manifest

          normalized = intent_text.downcase.strip
          manifest.each do |ext|
            next unless ext[:known_intents]

            ext[:known_intents].each do |ki|
              return ki if ki[:intent]&.downcase&.strip == normalized && ki[:confidence] >= 0.8
            end
          end
          nil
        end

        def chat(message:, model: nil, provider: nil)
          return nil unless available?

          uri = URI("#{daemon_url}/api/llm/chat")
          payload = Legion::JSON.dump({ message: message, model: model, provider: provider })
          response = post_json(uri, payload)

          return nil unless response && SUCCESS_CODES.include?(response.code.to_i)

          Legion::JSON.load(response.body)
        rescue StandardError => e
          Legion::Logging.warn("chat failed: #{e.message}") if defined?(Legion::Logging)
          nil
        end

        def reset!
          @daemon_url = nil
          @cache_file = nil
          @timeout = nil
          @manifest = nil
        end

        private

        def daemon_url
          @daemon_url || 'http://127.0.0.1:4567'
        end

        def post_json(uri, body)
          req = Net::HTTP::Post.new(uri)
          req['Content-Type'] = 'application/json'
          req.body = body
          Net::HTTP.start(uri.hostname, uri.port, open_timeout: @timeout, read_timeout: @timeout) { |h| h.request(req) }
        end

        def write_cache(data)
          return unless @cache_file

          FileUtils.mkdir_p(File.dirname(@cache_file))
          File.write(@cache_file, Legion::JSON.dump(data))
        rescue StandardError => e
          Legion::Logging.warn("write_cache failed: #{e.message}") if defined?(Legion::Logging)
          nil
        end
      end
    end
  end
end
