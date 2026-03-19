# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'fileutils'

module Legion
  module TTY
    module DaemonClient
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
        rescue StandardError
          false
        end

        def fetch_manifest
          uri = URI("#{daemon_url}/api/catalog")
          response = Net::HTTP.start(uri.hostname, uri.port, open_timeout: @timeout, read_timeout: @timeout) do |http|
            http.get(uri.path)
          end
          return nil unless response.code.to_i == 200

          body = ::JSON.parse(response.body, symbolize_names: true)
          @manifest = body[:data]
          write_cache(@manifest)
          @manifest
        rescue StandardError
          nil
        end

        def cached_manifest
          return @manifest if @manifest

          return nil unless @cache_file && File.exist?(@cache_file)

          @manifest = ::JSON.parse(File.read(@cache_file), symbolize_names: true)
        rescue StandardError
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
          req = Net::HTTP::Post.new(uri)
          req['Content-Type'] = 'application/json'
          req.body = ::JSON.dump({ message: message, model: model, provider: provider })

          response = Net::HTTP.start(uri.hostname, uri.port, open_timeout: @timeout, read_timeout: @timeout) do |http|
            http.request(req)
          end

          return nil unless [200, 201, 202].include?(response.code.to_i)

          ::JSON.parse(response.body, symbolize_names: true)
        rescue StandardError
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

        def write_cache(data)
          return unless @cache_file

          FileUtils.mkdir_p(File.dirname(@cache_file))
          File.write(@cache_file, ::JSON.dump(data))
        rescue StandardError
          nil
        end
      end
    end
  end
end
