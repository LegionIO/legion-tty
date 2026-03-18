# frozen_string_literal: true

require 'json'
require 'fileutils'
require_relative 'screen_manager'
require_relative 'hotkeys'
require_relative 'screens/onboarding'
require_relative 'screens/chat'

module Legion
  module TTY
    # rubocop:disable Metrics/ClassLength
    class App
      CONFIG_DIR = File.expand_path('~/.legionio/settings')

      attr_reader :config, :credentials, :screen_manager, :hotkeys, :llm_chat

      def self.run(argv = [])
        _ = argv
        app = new
        app.start
      rescue Interrupt
        app&.shutdown
      end

      def self.first_run?(config_dir: CONFIG_DIR)
        !File.exist?(File.join(config_dir, 'identity.json'))
      end

      def initialize(config_dir: CONFIG_DIR)
        @config_dir = config_dir
        @config = load_config
        @credentials = load_credentials
        @screen_manager = ScreenManager.new
        @hotkeys = Hotkeys.new
        @llm_chat = nil
      end

      def start
        setup_hotkeys
        if self.class.first_run?(config_dir: @config_dir)
          run_onboarding
        else
          run_chat
        end
      end

      def setup_hotkeys
        @hotkeys.register("\x04", 'Toggle dashboard (Ctrl+D)') do
          toggle_dashboard
        end
        @hotkeys.register("\x0C", 'Refresh screen (Ctrl+L)') do
          :refresh
        end
        @hotkeys.register('?', 'Show help overlay') do
          show_help_overlay
        end
      end

      def toggle_dashboard
        active = @screen_manager.active_screen
        if active.is_a?(Screens::Dashboard)
          @screen_manager.pop
        else
          require_relative 'screens/dashboard'
          dashboard = Screens::Dashboard.new(self)
          @screen_manager.push(dashboard)
        end
      end

      def show_help_overlay
        bindings = @hotkeys.list
        lines = bindings.map { |b| "  #{b[:key].inspect} - #{b[:description]}" }
        text = "Hotkeys:\n#{lines.join("\n")}"
        @screen_manager.show_overlay(text)
      end

      def run_onboarding
        onboarding = Screens::Onboarding.new(self)
        data = onboarding.activate
        save_config(data)
        @config = load_config
        @credentials = load_credentials
        run_chat
      end

      def run_chat
        rescan_environment
        setup_llm
        chat = Screens::Chat.new(self)
        @screen_manager.push(chat)
        chat.run
      end

      def setup_llm
        return unless @credentials[:provider] && @credentials[:api_key]

        provider = @credentials[:provider].to_sym
        api_key = @credentials[:api_key]
        configure_llm_provider(provider, api_key)
        @llm_chat = create_llm_chat(provider)
      rescue StandardError
        @llm_chat = nil
      end

      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      def rescan_environment
        identity_path = File.join(@config_dir, 'identity.json')
        return unless File.exist?(identity_path)

        Thread.new do
          scanner = Background::Scanner.new
          scan = scanner.scan_all
          identity = deep_symbolize(::JSON.parse(File.read(identity_path)))
          services = scan[:services]&.values&.select { |s| s[:running] }&.map { |s| s[:name] } || []
          repos = scan[:repos]&.map { |r| { name: r[:name], language: r[:language] } } || []
          identity[:environment] = {
            running_services: services,
            repos_count: repos.size,
            top_languages: repos.filter_map { |r| r[:language] }.tally.sort_by { |_, v| -v }.first(5).to_h
          }.compact
          File.write(identity_path, ::JSON.generate(identity))
          @config = load_config
        rescue StandardError
          nil
        end
      end

      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

      def save_config(data)
        FileUtils.mkdir_p(@config_dir)
        save_identity(data)
        save_credentials(data)
      end

      def shutdown
        @screen_manager.teardown_all
      end

      PROVIDER_MAP = {
        claude: :anthropic,
        azure: :openai
      }.freeze

      private

      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      def save_identity(data)
        identity = {
          name: data[:name],
          provider: data[:provider],
          created_at: Time.now.iso8601
        }

        # Kerberos identity
        if data[:identity].is_a?(Hash)
          id = data[:identity]
          identity[:kerberos] = {
            principal: id[:principal],
            username: id[:username],
            realm: id[:realm],
            display_name: id[:display_name],
            first_name: id[:first_name],
            last_name: id[:last_name],
            email: id[:email],
            title: id[:title],
            department: id[:department],
            company: id[:company],
            city: id[:city],
            state: id[:state],
            country: id[:country],
            tenure_years: id[:tenure_years]
          }.compact
        end

        # GitHub profile
        if data[:github].is_a?(Hash) && data[:github][:username]
          gh = data[:github]
          identity[:github] = {
            username: gh[:username],
            authenticated: gh[:authenticated],
            profile: gh[:profile],
            orgs: gh[:orgs]
          }.compact
        end

        # Environment scan
        if data[:scan].is_a?(Hash)
          scan = data[:scan]
          services = scan[:services]&.values&.select { |s| s[:running] }&.map { |s| s[:name] } || []
          repos = scan[:repos]&.map { |r| { name: r[:name], language: r[:language] } } || []
          identity[:environment] = {
            running_services: services,
            repos_count: repos.size,
            top_languages: repos.filter_map { |r| r[:language] }.tally.sort_by { |_, v| -v }.first(5).to_h
          }.compact
        end

        File.write(File.join(@config_dir, 'identity.json'), ::JSON.generate(identity))
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

      def load_credentials
        path = File.join(@config_dir, 'credentials.json')
        return {} unless File.exist?(path)

        deep_symbolize(::JSON.parse(File.read(path)))
      rescue ::JSON::ParserError, Errno::ENOENT
        {}
      end

      def configure_llm_provider(provider, api_key)
        llm_provider = PROVIDER_MAP[provider] || provider

        # Try Legion::LLM first (full stack)
        return if try_legion_llm(llm_provider, api_key)

        # Fallback: configure ruby_llm directly
        require 'ruby_llm'
        RubyLLM.configure do |c|
          case llm_provider
          when :anthropic then c.anthropic_api_key = api_key
          when :openai    then c.openai_api_key = api_key
          when :gemini    then c.gemini_api_key = api_key
          end
        end
      end

      def try_legion_llm(llm_provider, api_key)
        require 'legion/llm'
        return false unless defined?(Legion::Settings)

        Legion::Settings[:llm][:providers][llm_provider][:enabled] = true
        Legion::Settings[:llm][:providers][llm_provider][:api_key] = api_key
        Legion::LLM.start unless Legion::LLM.started?
        true
      rescue LoadError, StandardError
        false
      end

      def create_llm_chat(provider)
        llm_provider = PROVIDER_MAP[provider] || provider
        if defined?(Legion::LLM) && Legion::LLM.started?
          Legion::LLM.chat(provider: llm_provider)
        else
          RubyLLM.chat(provider: llm_provider)
        end
      end

      def save_credentials(data)
        credentials = { api_key: data[:api_key], provider: data[:provider] }
        creds_path = File.join(@config_dir, 'credentials.json')
        File.write(creds_path, ::JSON.generate(credentials))
        ::File.chmod(0o600, creds_path)
      end

      def load_config
        path = File.join(@config_dir, 'identity.json')
        return {} unless File.exist?(path)

        deep_symbolize(::JSON.parse(File.read(path)))
      rescue ::JSON::ParserError, Errno::ENOENT
        {}
      end

      def deep_symbolize(obj)
        case obj
        when Hash then obj.to_h { |k, v| [k.to_sym, deep_symbolize(v)] }
        when Array then obj.map { |v| deep_symbolize(v) }
        else obj
        end
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
