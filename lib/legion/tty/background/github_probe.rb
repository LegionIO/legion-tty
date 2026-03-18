# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module Legion
  module TTY
    module Background
      class GitHubProbe
        API_BASE = 'https://api.github.com'
        USER_AGENT = 'legion-tty/github-probe'

        def initialize(token: nil)
          @token = token || ENV.fetch('GITHUB_TOKEN', nil)
        end

        def infer_username(remote_url)
          return nil if remote_url.nil? || remote_url.empty?

          match = remote_url.match(%r{github\.com[:/]([^/]+)/})
          match ? match[1] : nil
        end

        def fetch_profile(username)
          data = api_get("/users/#{username}")
          return nil unless data.is_a?(Hash)

          {
            login: data['login'],
            name: data['name'],
            bio: data['bio'],
            repos: data['public_repos'],
            company: data['company'],
            location: data['location']
          }
        end

        def fetch_recent_events(username, limit: 10)
          data = api_get("/users/#{username}/events/public")
          return [] unless data.is_a?(Array)

          data.first(limit)
        end

        def fetch_recent_repos(username, limit: 10)
          data = api_get("/users/#{username}/repos?sort=updated")
          return [] unless data.is_a?(Array)

          data.first(limit)
        end

        def run_async(queue, remotes: [])
          Thread.new do
            username = remotes.filter_map { |r| infer_username(r) }.first
            result = build_result(username)
            queue.push({ type: :github_probe_complete, data: result })
          end
        end

        private

        def build_result(username)
          return { username: nil } unless username

          {
            username: username,
            profile: fetch_profile(username),
            events: fetch_recent_events(username),
            repos: fetch_recent_repos(username)
          }
        end

        def api_get(path)
          uri = URI("#{API_BASE}#{path}")
          http = build_http(uri)
          response = http.request(build_request(uri))
          ::JSON.parse(response.body)
        rescue StandardError
          nil
        end

        def build_http(uri)
          http = ::Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          http.open_timeout = 3
          http.read_timeout = 5
          http
        end

        def build_request(uri)
          request = ::Net::HTTP::Get.new(uri)
          request['User-Agent'] = USER_AGENT
          request['Accept'] = 'application/vnd.github+json'
          request['Authorization'] = "Bearer #{@token}" if @token
          request
        end
      end
    end
  end
end
