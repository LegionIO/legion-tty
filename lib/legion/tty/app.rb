# frozen_string_literal: true

require 'json'
require 'fileutils'
require_relative 'screen_manager'
require_relative 'hotkeys'
require_relative 'screens/onboarding'
require_relative 'screens/chat'

module Legion
  module TTY
    class App
      CONFIG_DIR = File.expand_path('~/.legionio/settings')

      attr_reader :config, :screen_manager, :hotkeys

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
        @screen_manager = ScreenManager.new
        @hotkeys = Hotkeys.new
      end

      def start
        if self.class.first_run?(config_dir: @config_dir)
          run_onboarding
        else
          run_chat
        end
      end

      def run_onboarding
        onboarding = Screens::Onboarding.new(self)
        data = onboarding.activate
        save_config(data)
        @config = load_config
        run_chat
      end

      def run_chat
        chat = Screens::Chat.new(self)
        @screen_manager.push(chat)
        chat.run
      end

      def save_config(data)
        FileUtils.mkdir_p(@config_dir)
        identity = { name: data[:name], provider: data[:provider], created_at: Time.now.iso8601 }
        File.write(File.join(@config_dir, 'identity.json'), ::JSON.generate(identity))
        credentials = { api_key: data[:api_key], provider: data[:provider] }
        creds_path = File.join(@config_dir, 'credentials.json')
        File.write(creds_path, ::JSON.generate(credentials))
        ::File.chmod(0o600, creds_path)
      end

      def shutdown
        @screen_manager.teardown_all
      end

      private

      def load_config
        path = File.join(@config_dir, 'identity.json')
        return {} unless File.exist?(path)

        parsed = ::JSON.parse(File.read(path))
        parsed.transform_keys(&:to_sym)
      rescue ::JSON::ParserError, Errno::ENOENT
        {}
      end
    end
  end
end
