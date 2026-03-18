# frozen_string_literal: true

require_relative '../screens/base'
require_relative '../components/digital_rain'
require_relative '../components/wizard_prompt'
require_relative '../background/scanner'
require_relative '../background/github_probe'
require_relative '../background/kerberos_probe'
require_relative '../boot_logger'
require_relative '../theme'

module Legion
  module TTY
    module Screens
      # rubocop:disable Metrics/ClassLength
      class Onboarding < Base
        TYPED_DELAY = 0.05

        def initialize(app, wizard: nil, output: $stdout, skip_rain: false)
          super(app)
          @wizard = wizard || Components::WizardPrompt.new
          @output = output
          @skip_rain = skip_rain
          @scan_queue = Queue.new
          @github_queue = Queue.new
          @github_quick_queue = Queue.new
          @kerberos_queue = Queue.new
          @llm_queue = Queue.new
          @kerberos_identity = nil
          @github_quick = nil
          @vault_results = nil
          @log = BootLogger.new
        end

        def activate
          @log.log('onboarding', 'activate started')
          start_background_threads
          run_rain unless @skip_rain
          run_intro
          config = run_wizard
          @log.log('wizard', "name=#{config[:name]} provider=#{config[:provider]}")
          run_vault_auth
          scan_data, github_data = collect_background_results
          run_reveal(name: config[:name], scan_data: scan_data, github_data: github_data)
          @log.log('onboarding', 'activate complete')
          build_onboarding_result(config, scan_data, github_data)
        end

        # rubocop:disable Metrics/AbcSize
        def run_rain
          require 'tty-cursor'
          require 'tty-font'
          width = terminal_width
          height = terminal_height
          rain = Components::DigitalRain.new(width: width, height: height)
          rain.run(duration_seconds: 20, fps: 18, output: @output)
          @output.print ::TTY::Cursor.clear_screen
          font = ::TTY::Font.new(:standard)
          title = font.write('LEGION')
          title.each_line do |line|
            @output.puts line.center(width)
          end
          @output.puts Theme.c(:muted, 'async cognition engine').center(width + 20)
          sleep 5
          @output.print ::TTY::Cursor.clear_screen
        end
        # rubocop:enable Metrics/AbcSize

        def run_intro
          # Collect background results that ran during the rain
          collect_kerberos_identity
          collect_github_quick

          sleep 2
          typed_output('...')
          sleep 1.2
          @output.puts
          @output.puts
          typed_output("Hello. I'm Legion.")
          @output.puts
          sleep 1.5
          if @kerberos_identity
            run_intro_with_identity
          else
            typed_output("Let's get you set up.")
            @output.puts
            @output.puts
          end
          run_intro_with_github if @github_quick
        end

        def run_wizard
          name = ask_for_name
          sleep 0.8
          typed_output("  Nice to meet you, #{name}.")
          @output.puts
          sleep 1
          providers = detect_providers
          default = select_provider_default(providers)
          @output.puts
          { name: name, provider: default, providers: providers }
        end

        def detect_providers
          typed_output('Detecting AI providers...')
          @output.puts
          @output.puts
          llm_data = drain_with_timeout(@llm_queue, timeout: 15)
          providers = llm_data&.dig(:data, :providers) || []
          @wizard.display_provider_results(providers)
          @output.puts
          providers
        end

        def select_provider_default(providers)
          working = providers.select { |p| p[:status] == :ok }
          if working.any?
            default = @wizard.select_default_provider(working)
            sleep 0.5
            typed_output("Connected. Let's chat.")
            default
          else
            typed_output('No AI providers detected. Configure one in ~/.legionio/settings/llm.json')
            nil
          end
        end

        def start_background_threads
          @log.log('threads', 'launching scanner, kerberos probe, github quick probe')
          @scanner = Background::Scanner.new(logger: @log)
          @github_probe = Background::GitHubProbe.new(logger: @log)
          @kerberos_probe = Background::KerberosProbe.new(logger: @log)
          @scanner.run_async(@scan_queue)
          @kerberos_probe.run_async(@kerberos_queue)
          @github_probe.run_quick_async(@github_quick_queue)
          require_relative '../background/llm_probe'
          @llm_probe = Background::LlmProbe.new(logger: @log)
          @llm_probe.run_async(@llm_queue)
        end

        def collect_background_results
          @log.log('collect', 'waiting for scanner results (10s timeout)')
          scan_result = drain_with_timeout(@scan_queue, timeout: 10)
          scan_data = scan_result&.dig(:data) || { services: {}, repos: [], tools: {} }
          log_scan_data(scan_data)

          # Now launch GitHub probe with discovered remotes
          remotes = scan_data[:repos]&.filter_map { |r| r[:remote] } || []
          @log.log('collect', "launching github probe with #{remotes.size} remotes")
          @github_probe.run_async(@github_queue, remotes: remotes, quick_profile: @github_quick)
          github_result = drain_with_timeout(@github_queue, timeout: 8)
          github_data = github_result&.dig(:data)
          log_github_data(github_data)
          [scan_data, github_data]
        end

        def run_reveal(name:, scan_data:, github_data:)
          require 'tty-box'
          @output.puts
          typed_output('One moment...')
          @output.puts
          sleep 1.5
          summary = build_summary(name: name, scan_data: scan_data, github_data: github_data)
          box = ::TTY::Box.frame(summary, padding: 1, border: :thick)
          @output.puts box
          @output.puts
          @wizard.confirm('Does this look right?')
          @output.puts
          sleep 0.8
          typed_output("Let's chat.")
          @output.puts
          sleep 1
        end

        def build_summary(name:, scan_data:, github_data:)
          lines = ["Hello, #{name}!", '', "Here's what I found:"]
          lines.concat(identity_summary_lines)
          lines.concat(scan_summary_lines(scan_data))
          lines.concat(dotfiles_summary_lines(scan_data))
          lines.concat(github_summary_lines(github_data))
          lines.concat(vault_summary_lines)
          lines.join("\n")
        end

        private

        def run_vault_auth
          return unless vault_clusters_configured?

          count = vault_cluster_count
          @output.puts
          typed_output("I found #{count} Vault cluster#{'s' if count != 1}.")
          @output.puts
          return unless @wizard.confirm('Connect now?')

          run_vault_auth_credentials
        end

        def run_vault_auth_credentials
          username = @wizard.ask_with_default('Username:', default_vault_username)
          password = @wizard.ask_secret('Password:')
          return if password.nil? || password.empty?

          @output.puts
          typed_output('Authenticating...')
          @output.puts

          @vault_results = perform_vault_auth(username, password)
          display_vault_results(@vault_results)
        end

        def vault_clusters_configured?
          return false unless defined?(Legion::Settings)

          clusters = Legion::Settings.dig(:crypt, :vault, :clusters)
          clusters.is_a?(Hash) && clusters.any?
        rescue StandardError
          false
        end

        def vault_cluster_count
          Legion::Settings.dig(:crypt, :vault, :clusters)&.size || 0
        rescue StandardError
          0
        end

        def default_vault_username
          if @kerberos_identity&.dig(:samaccountname)
            @kerberos_identity[:samaccountname]
          else
            ENV.fetch('USER', 'unknown')
          end
        end

        def perform_vault_auth(username, password)
          return {} unless defined?(Legion::Crypt) && Legion::Crypt.respond_to?(:ldap_login_all)

          Legion::Crypt.ldap_login_all(username: username, password: password)
        rescue StandardError => e
          @log.log('vault', "LDAP auth failed: #{e.message}")
          {}
        end

        def display_vault_results(results)
          results.each do |name, result|
            if result[:error]
              @output.puts "  #{Theme.c(:error, 'X')} #{name}: #{result[:error]}"
            else
              policies = result[:policies]&.size || 0
              @output.puts "  #{Theme.c(:success, 'ok')} #{name}: connected (#{policies} policies)"
            end
          end
          @output.puts
          sleep 1
        end

        def build_onboarding_result(config, scan_data, github_data)
          {
            **config,
            identity: @kerberos_identity,
            github: github_data,
            scan: scan_data
          }
        end

        def collect_github_quick
          @log.log('github', 'collecting quick profile (3s timeout)')
          result = drain_with_timeout(@github_quick_queue, timeout: 3)
          @github_quick = result&.dig(:data)
          if @github_quick
            @log.log('github', "quick profile: #{@github_quick[:username]} " \
                               "commits_week=#{@github_quick[:commits_this_week]} " \
                               "commits_month=#{@github_quick[:commits_this_month]}")
          else
            @log.log('github', 'no quick profile available')
          end
        end

        # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        def run_intro_with_github
          gh = @github_quick
          name = gh[:name] || gh[:username]

          if gh[:commits_this_week]&.positive?
            typed_output("#{gh[:commits_this_week]} commits this week, #{name}. You've been busy.")
            @output.puts
            sleep 1
          elsif gh[:commits_this_month]&.positive?
            typed_output("#{gh[:commits_this_month]} commits this month across GitHub.")
            @output.puts
            sleep 1
          end

          total = (gh[:public_repos] || 0) + (gh[:private_repos] || 0)
          if total.positive?
            typed_output("#{total} repositories. I can work with that.")
            @output.puts
            sleep 0.8
          end

          @output.puts
        end
        # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

        def collect_kerberos_identity
          @log.log('kerberos', 'collecting identity (2s timeout)')
          result = drain_with_timeout(@kerberos_queue, timeout: 2)
          @kerberos_identity = result&.dig(:data)
          if @kerberos_identity
            @log.log_hash('kerberos', 'identity found', @kerberos_identity)
          else
            @log.log('kerberos', 'no identity found (klist failed or no ticket)')
          end
        end

        # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        def run_intro_with_identity
          id = @kerberos_identity
          typed_output("I see you, #{id[:first_name]}.")
          @output.puts
          sleep 1.2

          if id[:title]
            typed_output("#{id[:title]}, #{id[:company] || id[:department]}")
            @output.puts
            sleep 0.8
          end

          if id[:city] && id[:state]
            typed_output("#{id[:city]}, #{id[:state]}")
            @output.puts
            sleep 0.8
          end

          if id[:tenure_years]
            typed_output("#{format_tenure(id[:tenure_years])} and counting.")
            @output.puts
            sleep 1
          end

          @output.puts
          typed_output("I've been looking forward to meeting you.")
          @output.puts
          @output.puts
        end
        # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

        def ask_for_name
          if @kerberos_identity
            @wizard.ask_name_with_default(@kerberos_identity[:first_name])
          else
            @wizard.ask_name
          end
        end

        # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
        def identity_summary_lines
          return [] unless @kerberos_identity

          id = @kerberos_identity
          lines = ['']
          lines << "Identity: #{id[:display_name]} (#{id[:principal]})"
          lines << "  Title: #{id[:title]}" if id[:title]
          lines << "  Org: #{[id[:department], id[:company]].compact.join(' / ')}" if id[:department] || id[:company]
          lines << "  Location: #{[id[:city], id[:state], id[:country]].compact.join(', ')}" if id[:city]
          lines << "  Tenure: #{format_tenure(id[:tenure_years])}" if id[:tenure_years]
          lines << "  Email: #{id[:email]}" if id[:email]
          lines
        end
        # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity

        def scan_summary_lines(scan_data)
          return [] unless scan_data.is_a?(Hash)

          services = scan_data[:services]
          return [] unless services.is_a?(Hash)

          running = services.values.select { |s| s[:running] }.map { |s| s[:name] }
          return [] if running.empty?

          ['', "Running services: #{running.join(', ')}"]
        end

        def dotfiles_summary_lines(scan_data)
          return [] unless scan_data.is_a?(Hash)

          dotfiles = scan_data[:dotfiles]
          return [] unless dotfiles.is_a?(Hash)

          lines = []
          lines.concat(git_summary_lines(dotfiles[:git]))
          lines.concat(jfrog_summary_lines(dotfiles[:jfrog]))
          lines.concat(terraform_summary_lines(dotfiles[:terraform]))
          lines
        end

        def git_summary_lines(git)
          return [] unless git.is_a?(Hash)

          lines = ['', "Git: #{git[:name]} <#{git[:email]}>"]
          lines << "  Signing key: #{git[:signing_key]}" if git[:signing_key]
          lines
        end

        def jfrog_summary_lines(jfrog)
          return [] unless jfrog.is_a?(Array) && !jfrog.empty?

          lines = ['', 'JFrog Artifactory:']
          jfrog.each { |s| lines << "  #{s[:server_id]}: #{s[:url]} (#{s[:user]})" }
          lines
        end

        def vault_summary_lines
          return [] unless @vault_results.is_a?(Hash) && @vault_results.any?

          lines = ['', 'Vault:']
          @vault_results.each do |name, result|
            lines << if result[:error]
                       "  #{name}: failed (#{result[:error]})"
                     else
                       "  #{name}: connected"
                     end
          end
          lines
        end

        def terraform_summary_lines(dotfiles_tf)
          return [] unless dotfiles_tf.is_a?(Hash) && dotfiles_tf[:hosts]&.any?

          ['', "Terraform: #{dotfiles_tf[:hosts].join(', ')}"]
        end

        # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength
        def github_summary_lines(github_data)
          return [] unless github_data.is_a?(Hash)

          username = github_data[:username]
          return [] unless username

          lines = ['', "GitHub: #{username}"]
          profile = github_data[:profile]
          if profile.is_a?(Hash)
            lines << "  Name: #{profile[:name]}" if profile[:name]
            lines << "  Company: #{profile[:company]}" if profile[:company]
            lines << "  Public repos: #{profile[:public_repos]}" if profile[:public_repos]
            lines << "  Private repos: #{profile[:private_repos]}" if profile[:private_repos]
            lines << "  Followers: #{profile[:followers]}" if profile[:followers]
          end

          orgs = github_data[:orgs]
          lines << "  Orgs: #{orgs.map { |o| o[:login] }.join(', ')}" if orgs.is_a?(Array) && !orgs.empty?

          prs = github_data[:recent_prs]
          if prs.is_a?(Array) && !prs.empty?
            lines << '  Recent PRs:'
            prs.first(3).each do |pr|
              lines << "    #{pr[:state] == 'open' ? '○' : '●'} #{pr[:repo]}: #{pr[:title]}"
            end
          end

          notifs = github_data[:notifications]
          lines << "  Notifications: #{notifs.size} unread" if notifs.is_a?(Array) && !notifs.empty?

          lines
        end
        # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength

        # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        def format_tenure(tenure)
          return tenure.to_s unless tenure.is_a?(Hash)

          parts = []
          y = tenure[:years]
          m = tenure[:months]
          d = tenure[:days]
          parts << "#{y} year#{'s' if y != 1}" if y&.positive?
          parts << "#{m} month#{'s' if m != 1}" if m&.positive?
          parts << "#{d} day#{'s' if d != 1}" if d&.positive?
          parts.join(', ')
        end
        # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

        def typed_output(text, delay: TYPED_DELAY)
          text.chars.each do |char|
            @output.print Theme.c(:primary, char)
            @output.flush if @output.respond_to?(:flush)
            sleep delay
          end
        end

        # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        def log_scan_data(scan_data)
          services = scan_data[:services] || {}
          running = services.values.select { |s| s[:running] }.map { |s| s[:name] }
          stopped = services.values.reject { |s| s[:running] }.map { |s| s[:name] }
          @log.log('scanner', "services running: #{running.join(', ').then { |s| s.empty? ? 'none' : s }}")
          @log.log('scanner', "services stopped: #{stopped.join(', ').then { |s| s.empty? ? 'none' : s }}")

          repos = scan_data[:repos] || []
          @log.log('scanner', "git repos found: #{repos.size}")
          repos.each do |r|
            @log.log('scanner', "  repo: #{r[:name]} branch=#{r[:branch]} lang=#{r[:language]} remote=#{r[:remote]}")
          end

          tools = scan_data[:tools] || {}
          @log.log('scanner', "top shell commands: #{tools.first(10).map { |k, v| "#{k}(#{v})" }.join(', ')}")

          configs = scan_data[:configs] || []
          @log.log('scanner', "config files: #{configs.join(', ').then { |s| s.empty? ? 'none' : s }}")
        end
        # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

        # rubocop:disable Metrics/AbcSize
        def log_github_data(github_data)
          unless github_data.is_a?(Hash)
            @log.log('github', 'no data returned')
            return
          end
          @log.log('github', "username: #{github_data[:username] || 'unknown'}")
          @log.log('github', "authenticated: #{github_data[:authenticated]}")

          profile = github_data[:profile]
          if profile.is_a?(Hash)
            @log.log('github', "  name: #{profile[:name]}")
            @log.log('github', "  email: #{profile[:email]}")
            @log.log('github', "  company: #{profile[:company]}")
            @log.log('github', "  location: #{profile[:location]}")
            @log.log('github', "  public_repos: #{profile[:public_repos]}")
            @log.log('github', "  private_repos: #{profile[:private_repos]}")
            @log.log('github', "  followers: #{profile[:followers]} following: #{profile[:following]}")
          end

          orgs = github_data[:orgs] || []
          @log.log('github', "orgs: #{orgs.map { |o| o[:login] }.join(', ').then { |s| s.empty? ? 'none' : s }}")

          log_github_repos(github_data)
          log_github_activity(github_data)
        end
        # rubocop:enable Metrics/AbcSize

        # rubocop:disable Metrics/AbcSize
        def log_github_repos(github_data)
          public_repos = github_data[:public_repos] || []
          @log.log('github', "public repos: #{public_repos.size}")
          public_repos.first(5).each do |r|
            @log.log('github', "  #{r[:full_name]} (#{r[:language]}) updated=#{r[:updated_at]}")
          end

          private_repos = github_data[:private_repos] || []
          @log.log('github', "private repos: #{private_repos.size}")
          private_repos.first(5).each do |r|
            @log.log('github', "  #{r[:full_name]} (#{r[:language]}) updated=#{r[:updated_at]}")
          end

          starred = github_data[:starred] || []
          @log.log('github', "recently starred: #{starred.size}")
        end
        # rubocop:enable Metrics/AbcSize

        # rubocop:disable Metrics/AbcSize
        def log_github_activity(github_data)
          prs = github_data[:recent_prs] || []
          @log.log('github', "recent PRs: #{prs.size}")
          prs.first(5).each do |pr|
            @log.log('github', "  [#{pr[:state]}] #{pr[:repo]}: #{pr[:title]}")
          end

          events = github_data[:events] || []
          @log.log('github', "recent events: #{events.size}")
          events.first(5).each do |e|
            @log.log('github', "  #{e[:type]} on #{e[:repo]} at #{e[:created_at]}")
          end

          notifs = github_data[:notifications] || []
          @log.log('github', "notifications: #{notifs.size}")
          notifs.first(5).each do |n|
            @log.log('github', "  [#{n[:reason]}] #{n[:repo]}: #{n[:title]}")
          end
        end
        # rubocop:enable Metrics/AbcSize

        def drain_with_timeout(queue, timeout:)
          deadline = Time.now + timeout
          loop do
            return queue.pop(true) unless queue.empty?
            return nil if Time.now >= deadline

            sleep 0.1
          end
        rescue ThreadError
          nil
        end

        def terminal_width
          require 'tty-screen'
          ::TTY::Screen.width
        rescue StandardError
          80
        end

        def terminal_height
          require 'tty-screen'
          ::TTY::Screen.height
        rescue StandardError
          24
        end
      end
      # rubocop:enable Metrics/ClassLength
    end
  end
end
