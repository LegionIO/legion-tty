# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module Legion
  module TTY
    module Background
      # rubocop:disable Metrics/ClassLength
      class GitHubProbe
        API_BASE = 'https://api.github.com'
        USER_AGENT = 'legion-tty/github-probe'

        def initialize(token: nil, logger: nil)
          @log = logger
          @token = token || resolve_token
        end

        # rubocop:disable Metrics/AbcSize
        def run_quick_async(queue)
          Thread.new do
            unless @token
              @log&.log('github', 'quick probe skipped (no token)')
              queue.push({ type: :github_quick_complete, data: nil })
              return
            end

            @log&.log('github', 'quick probe: fetching /user + recent commits')
            t0 = Time.now
            result = fetch_quick_profile
            elapsed = ((Time.now - t0) * 1000).round
            @log&.log('github', "quick probe complete in #{elapsed}ms")
            queue.push({ type: :github_quick_complete, data: result })
          rescue StandardError => e
            @log&.log('github', "quick probe ERROR: #{e.class}: #{e.message}")
            queue.push({ type: :github_quick_error, error: e.message })
          end
        end
        # rubocop:enable Metrics/AbcSize

        # rubocop:disable Metrics/AbcSize
        def run_async(queue, remotes: [], quick_profile: nil)
          Thread.new do
            @log&.log('github', "probing with #{remotes.size} remotes: #{remotes.first(5).inspect}")
            @log&.log('github', "token: #{@token ? 'present' : 'NONE'}")
            @log&.log('github', "quick_profile: #{quick_profile ? 'reusing' : 'none'}")
            t0 = Time.now
            result = if @token
                       build_authenticated_result(remotes, quick_profile: quick_profile)
                     else
                       build_public_result(remotes)
                     end
            elapsed = ((Time.now - t0) * 1000).round
            @log&.log('github', "probe complete in #{elapsed}ms")
            queue.push({ type: :github_probe_complete, data: result })
          rescue StandardError => e
            @log&.log('github', "ERROR: #{e.class}: #{e.message}")
            queue.push({ type: :github_error, error: e.message })
          end
        end
        # rubocop:enable Metrics/AbcSize

        private

        # --- Quick profile: just /user + commit count (runs during rain) ---

        # rubocop:disable Metrics/AbcSize
        def fetch_quick_profile
          user_data = api_get('/user')
          return nil unless user_data.is_a?(Hash) && user_data['login']

          username = user_data['login']
          @log&.log('github', "quick: authenticated as #{username}")

          week_ago = (Time.now - (7 * 86_400)).strftime('%Y-%m-%d')
          month_ago = (Time.now - (30 * 86_400)).strftime('%Y-%m-%d')

          commits_week = count_commits(username, since: week_ago)
          commits_month = count_commits(username, since: month_ago)
          @log&.log('github', "quick: commits this week=#{commits_week} this month=#{commits_month}")

          {
            username: username,
            name: user_data['name'],
            public_repos: user_data['public_repos'],
            private_repos: user_data['total_private_repos'],
            followers: user_data['followers'],
            created_at: user_data['created_at'],
            commits_this_week: commits_week,
            commits_this_month: commits_month
          }
        end
        # rubocop:enable Metrics/AbcSize

        def count_commits(username, since:)
          query = URI.encode_www_form_component("author:#{username} committer-date:>#{since}")
          uri = URI("#{API_BASE}/search/commits?q=#{query}&per_page=1")
          http = build_http(uri)
          request = build_request(uri)
          request['Accept'] = 'application/vnd.github.cloak-preview+json'
          response = http.request(request)
          data = ::JSON.parse(response.body)
          return 0 unless data.is_a?(Hash)

          data['total_count'] || 0
        rescue StandardError => e
          Legion::Logging.debug("count_commits failed: #{e.message}") if defined?(Legion::Logging)
          0
        end

        # --- Authenticated path: GET /user tells us who we are ---

        # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        def build_authenticated_result(remotes, quick_profile: nil)
          if quick_profile
            username = quick_profile[:username]
            @log&.log('github', "reusing quick profile for: #{username}")
            profile = quick_profile
          else
            user_data = api_get('/user')
            unless user_data.is_a?(Hash) && user_data['login']
              @log&.log('github', 'authenticated /user failed, falling back to public')
              return build_public_result(remotes)
            end
            username = user_data['login']
            @log&.log('github', "authenticated as: #{username}")
            profile = extract_profile(user_data)
          end
          orgs = fetch_orgs
          private_repos = fetch_private_repos
          public_repos = fetch_public_repos(username)
          recent_prs = fetch_recent_prs(username)
          events = fetch_recent_events(username)
          notifications = fetch_notifications
          starred = fetch_starred

          {
            username: username,
            authenticated: true,
            profile: profile,
            orgs: orgs,
            private_repos: private_repos,
            public_repos: public_repos,
            recent_prs: recent_prs,
            events: events,
            notifications: notifications,
            starred: starred
          }
        end
        # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

        def extract_profile(data)
          {
            login: data['login'],
            name: data['name'],
            bio: data['bio'],
            public_repos: data['public_repos'],
            private_repos: data['total_private_repos'],
            company: data['company'],
            location: data['location'],
            email: data['email'],
            created_at: data['created_at'],
            followers: data['followers'],
            following: data['following']
          }
        end

        def fetch_orgs
          data = api_get('/user/orgs')
          return [] unless data.is_a?(Array)

          data.map { |o| { login: o['login'], description: o['description'] } }
        end

        def fetch_private_repos(limit: 10)
          data = api_get("/user/repos?visibility=private&sort=updated&per_page=#{limit}")
          return [] unless data.is_a?(Array)

          data.map { |r| extract_repo(r) }
        end

        # rubocop:disable Metrics/AbcSize
        def fetch_recent_prs(username, limit: 10)
          query = URI.encode_www_form_component("author:#{username} type:pr sort:updated")
          data = api_get("/search/issues?q=#{query}&per_page=#{limit}")
          return [] unless data.is_a?(Hash) && data['items'].is_a?(Array)

          data['items'].map do |pr|
            repo_url = pr['repository_url']
            repo_name = repo_url ? repo_url.split('/').last(2).join('/') : nil
            {
              title: pr['title'],
              repo: repo_name,
              state: pr['state'],
              created_at: pr['created_at'],
              updated_at: pr['updated_at'],
              url: pr['html_url']
            }
          end
        end
        # rubocop:enable Metrics/AbcSize

        def fetch_notifications(limit: 10)
          data = api_get("/notifications?per_page=#{limit}")
          return [] unless data.is_a?(Array)

          data.map do |n|
            {
              reason: n['reason'],
              title: n.dig('subject', 'title'),
              type: n.dig('subject', 'type'),
              repo: n.dig('repository', 'full_name'),
              updated_at: n['updated_at']
            }
          end
        end

        def fetch_starred(limit: 10)
          data = api_get("/user/starred?per_page=#{limit}&sort=created&direction=desc")
          return [] unless data.is_a?(Array)

          data.map { |r| extract_repo(r) }
        end

        # --- Public path: infer username from remotes ---

        def build_public_result(remotes)
          username = remotes.filter_map { |r| infer_username(r) }.first
          @log&.log('github', "inferred username: #{username || 'none'}")
          return { username: nil } unless username

          profile_data = api_get("/users/#{username}")
          profile = profile_data.is_a?(Hash) ? extract_profile(profile_data) : nil

          {
            username: username,
            authenticated: false,
            profile: profile,
            public_repos: fetch_public_repos(username),
            events: fetch_recent_events(username)
          }
        end

        def infer_username(remote_url)
          return nil if remote_url.nil? || remote_url.empty?

          match = remote_url.match(%r{github\.com[:/]([^/]+)/})
          match ? match[1] : nil
        end

        # --- Shared fetchers ---

        def fetch_public_repos(username, limit: 10)
          data = api_get("/users/#{username}/repos?sort=updated&per_page=#{limit}")
          return [] unless data.is_a?(Array)

          data.map { |r| extract_repo(r) }
        end

        def fetch_recent_events(username, limit: 10)
          data = api_get("/users/#{username}/events/public?per_page=#{limit}")
          return [] unless data.is_a?(Array)

          data.first(limit).map do |e|
            {
              type: e['type'],
              repo: e.dig('repo', 'name'),
              created_at: e['created_at']
            }
          end
        end

        def extract_repo(repo)
          {
            full_name: repo['full_name'],
            language: repo['language'],
            private: repo['private'],
            updated_at: repo['updated_at'],
            description: repo['description']
          }
        end

        # --- Token resolution ---

        def resolve_token
          env_token = ENV.fetch('GITHUB_TOKEN', nil) ||
                      ENV.fetch('GH_TOKEN', nil) ||
                      ENV.fetch('GITHUB_PERSONAL_ACCESS_TOKEN', nil)
          if env_token
            @log&.log('github', 'token source: environment variable')
            return env_token
          end

          gh_token = token_from_gh_cli
          if gh_token
            @log&.log('github', 'token source: gh CLI')
            return gh_token
          end

          @log&.log('github', 'no token found (no env var, no gh CLI)')
          nil
        end

        def token_from_gh_cli
          gh_path = `which gh 2>/dev/null`.strip
          return nil if gh_path.empty?

          @log&.log('github', "found gh CLI at #{gh_path}")

          status = `gh auth status 2>&1`
          @log&.log('github', "gh auth status: #{status.lines.first&.strip}")
          return nil unless $CHILD_STATUS&.success?

          token = `gh auth token 2>/dev/null`.strip
          return nil if token.empty?

          token
        rescue StandardError => e
          @log&.log('github', "gh CLI error: #{e.message}")
          nil
        end
        # --- HTTP ---

        def api_get(path)
          uri = URI("#{API_BASE}#{path}")
          http = build_http(uri)
          response = http.request(build_request(uri))
          ::JSON.parse(response.body)
        rescue StandardError => e
          Legion::Logging.debug("api_get failed: #{e.message}") if defined?(Legion::Logging)
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
      # rubocop:enable Metrics/ClassLength
    end
  end
end
