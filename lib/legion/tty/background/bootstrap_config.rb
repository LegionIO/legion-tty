# frozen_string_literal: true

require 'base64'
require 'fileutils'
require 'json'
require 'net/http'
require 'uri'

module Legion
  module TTY
    module Background
      class BootstrapConfig
        ENV_KEY = 'LEGIONIO_BOOTSTRAP_CONFIG'
        SETTINGS_DIR = File.expand_path('~/.legionio/settings')

        def initialize(logger: nil)
          @log = logger
        end

        def run_async(queue)
          Thread.new do
            result = perform_bootstrap
            queue.push(result)
          rescue StandardError => e
            @log&.log('bootstrap', "ERROR: #{e.class}: #{e.message}")
            queue.push({ type: :bootstrap_error, error: e.message })
          end
        end

        private

        def perform_bootstrap
          @log&.log('bootstrap', 'checking for bootstrap config')
          source = ENV.fetch(ENV_KEY, nil)
          return skip_result unless source && !source.empty?

          @log&.log('bootstrap', "source: #{source}")
          body = fetch_source(source)
          config = parse_payload(body)
          written = write_split_config(config)
          @log&.log('bootstrap', "wrote #{written.size} config files: #{written.join(', ')}")
          { type: :bootstrap_complete, data: { files: written, sections: config.keys.map(&:to_s) } }
        end

        def skip_result
          @log&.log('bootstrap', "#{ENV_KEY} not set, skipping")
          { type: :bootstrap_complete, data: nil }
        end

        def fetch_source(source)
          if source.match?(%r{\Ahttps?://}i)
            fetch_http(source)
          else
            path = File.expand_path(source)
            raise "File not found: #{source}" unless File.exist?(path)

            File.read(path)
          end
        end

        def fetch_http(url)
          uri = URI.parse(url)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = uri.scheme == 'https'
          http.open_timeout = 10
          http.read_timeout = 10
          request = Net::HTTP::Get.new(uri)
          response = http.request(request)
          raise "HTTP #{response.code}: #{response.message}" unless response.is_a?(Net::HTTPSuccess)

          response.body
        end

        def parse_payload(body)
          parsed = ::JSON.parse(body, symbolize_names: true)
          raise 'Config must be a JSON object' unless parsed.is_a?(Hash)

          parsed
        rescue ::JSON::ParserError
          decoded = Base64.decode64(body)
          parsed = ::JSON.parse(decoded, symbolize_names: true)
          raise 'Config must be a JSON object' unless parsed.is_a?(Hash)

          parsed
        end

        def write_split_config(config)
          FileUtils.mkdir_p(SETTINGS_DIR)
          written = []

          config.each do |key, value|
            next unless value.is_a?(Hash)

            path = File.join(SETTINGS_DIR, "#{key}.json")
            content = { key => value }

            if File.exist?(path)
              existing = ::JSON.parse(File.read(path), symbolize_names: true)
              content = deep_merge(existing, content)
            end

            File.write(path, ::JSON.pretty_generate(content))
            written << "#{key}.json"
          end

          written
        end

        def deep_merge(base, overlay)
          base.merge(overlay) do |_key, old_val, new_val|
            if old_val.is_a?(Hash) && new_val.is_a?(Hash)
              deep_merge(old_val, new_val)
            else
              new_val
            end
          end
        end
      end
    end
  end
end
