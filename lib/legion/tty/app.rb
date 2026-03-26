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

      # Key normalization: raw escape sequences and control chars to symbols
      KEY_MAP = {
        "\e[A" => :up, "\e[B" => :down, "\e[C" => :right, "\e[D" => :left,
        "\r" => :enter, "\n" => :enter, "\e" => :escape,
        "\e[5~" => :page_up, "\e[6~" => :page_down,
        "\e[H" => :home, "\eOH" => :home, "\e[F" => :end, "\eOF" => :end,
        "\e[1~" => :home, "\e[4~" => :end,
        "\x7f" => :backspace, "\b" => :backspace, "\t" => :tab,
        "\x03" => :ctrl_c, "\x04" => :ctrl_d,
        "\x01" => :ctrl_a, "\x05" => :ctrl_e,
        "\x0B" => :ctrl_k, "\x0C" => :ctrl_l, "\x13" => :ctrl_s,
        "\x15" => :ctrl_u
      }.freeze

      attr_reader :config, :credentials, :screen_manager, :hotkeys, :llm_chat, :input_bar

      def self.run(argv = [])
        opts = parse_argv(argv)
        app = new(**opts)
        app.start
      rescue Interrupt => e
        Legion::Logging.debug("app interrupted: #{e.message}") if defined?(Legion::Logging)
        app&.shutdown
      end

      def self.parse_argv(argv)
        opts = {}
        opts[:skip_rain] = true if argv.include?('--skip-rain')
        opts
      end

      def self.first_run?(config_dir: CONFIG_DIR)
        !File.exist?(File.join(config_dir, 'identity.json'))
      end

      def initialize(config_dir: CONFIG_DIR, skip_rain: false)
        @config_dir = config_dir
        @skip_rain = skip_rain
        @config = load_config
        @credentials = load_credentials
        @screen_manager = ScreenManager.new
        @hotkeys = Hotkeys.new
        @llm_chat = nil
        @input_bar = nil
        @running = false
        @prev_frame = []
        @raw_mode = false
      end

      def start
        setup_hotkeys
        run_onboarding if self.class.first_run?(config_dir: @config_dir)
        setup_for_chat
        run_loop
      end

      # Public: called by screens (e.g., Chat during LLM streaming) to force a re-render
      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      def render_frame
        width = terminal_width
        height = terminal_height
        active = @screen_manager.active_screen
        return unless active

        has_input = active.respond_to?(:needs_input_bar?) && active.needs_input_bar?
        screen_height = has_input ? height - 1 : height

        lines = active.render(width, screen_height)
        lines << @input_bar.render_line(width: width) if has_input && @input_bar

        lines = lines[0, height] if lines.size > height
        lines += Array.new(height - lines.size, '') if lines.size < height

        lines = composite_overlay(lines, width, height) if @screen_manager.overlay

        write_differential(lines, width)

        if has_input && @input_bar
          col = [@input_bar.cursor_column, width - 1].min
          $stdout.print cursor.move_to(col, height - 1)
        end

        $stdout.flush
      rescue StandardError => e
        Legion::Logging.warn("render_frame failed: #{e.message}") if defined?(Legion::Logging)
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

      # Temporarily exit raw mode for blocking prompts (TTY::Prompt, etc.)
      def with_cooked_mode(&)
        return yield unless @raw_mode

        $stdout.print cursor.show
        $stdin.cooked(&)
        $stdout.print cursor.hide
        @prev_frame = []
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

      def shutdown
        @running = false
        @screen_manager.teardown_all
      end

      private

      # --- Boot ---

      def setup_for_chat
        rescan_environment
        setup_llm
        cfg = safe_config
        name = cfg[:name] || 'User'
        @input_bar = Components::InputBar.new(name: name, completions: Screens::Chat::SLASH_COMMANDS)
        chat = Screens::Chat.new(self)
        @screen_manager.push(chat)
      end

      # --- Event Loop ---

      # rubocop:disable Metrics/AbcSize
      def run_loop
        require 'io/console'

        @running = true
        @raw_mode = true
        $stdout.print cursor.hide
        $stdout.print cursor.clear_screen

        $stdin.raw do |raw_in|
          while @running
            render_frame
            timeout = needs_refresh? ? 0.05 : nil
            raw_key = read_raw_key(raw_in, timeout: timeout)
            next unless raw_key

            key = normalize_key(raw_key)
            dispatch_key(key)
          end
        end
      rescue Interrupt
        nil
      ensure
        @raw_mode = false
        $stdout.print cursor.show
        $stdout.print cursor.move_to(0, terminal_height - 1)
        $stdout.puts
        shutdown
      end
      # rubocop:enable Metrics/AbcSize

      def needs_refresh?
        active = @screen_manager.active_screen
        active.respond_to?(:streaming?) && active.streaming?
      end

      def normalize_key(raw)
        KEY_MAP[raw] || raw
      end

      # --- Key Dispatch ---

      def dispatch_key(key)
        if key == :ctrl_c
          @running = false
          return
        end

        if key == :escape && @screen_manager.overlay
          @screen_manager.dismiss_overlay
          return
        end

        result = @hotkeys.handle(key)
        if result
          handle_hotkey_result(result)
          return
        end

        active = @screen_manager.active_screen
        return unless active

        if active.respond_to?(:needs_input_bar?) && active.needs_input_bar? && @input_bar
          dispatch_to_input_screen(active, key)
        else
          dispatch_to_screen(active, key)
        end
      end

      def dispatch_to_input_screen(screen, key)
        result = @input_bar.handle_key(key)
        if result.is_a?(Array) && result[0] == :submit
          screen_result = screen.handle_line(result[1])
          handle_screen_result(screen_result)
        elsif result == :pass
          screen_result = screen.handle_input(key)
          handle_screen_result(screen_result)
        end
      end

      def dispatch_to_screen(screen, key)
        result = screen.handle_input(key)
        handle_screen_result(result)
      end

      def handle_screen_result(result)
        case result
        when :pop_screen then @screen_manager.pop
        when :quit then @running = false
        end
      end

      def handle_hotkey_result(result)
        case result
        when :command_palette
          active = @screen_manager.active_screen
          active.send(:handle_palette) if active.respond_to?(:handle_palette, true)
        when :session_picker
          active = @screen_manager.active_screen
          active.send(:handle_sessions_picker) if active.respond_to?(:handle_sessions_picker, true)
        end
      end

      # --- Raw Key Reading ---

      def read_raw_key(io, timeout: nil)
        return nil unless io.wait_readable(timeout)

        c = io.getc
        return nil unless c

        return c unless c == "\e"

        read_escape_sequence(io)
      end

      def read_escape_sequence(io)
        return "\e" unless io.wait_readable(0.05)

        c2 = io.getc
        return "\e" unless c2

        if c2 == '['
          read_csi_sequence(io)
        elsif c2 == 'O'
          c3 = io.wait_readable(0.05) ? io.getc : nil
          c3 ? "\eO#{c3}" : "\eO"
        else
          "\e#{c2}"
        end
      end

      def read_csi_sequence(io)
        seq = +"\e["
        loop do
          break unless io.wait_readable(0.05)

          c = io.getc
          break unless c

          seq << c
          break if c.ord.between?(0x40, 0x7E)
        end
        seq
      end

      # --- Rendering ---

      # rubocop:disable Metrics/AbcSize
      def composite_overlay(lines, width, height)
        require 'tty-box'
        text = @screen_manager.overlay.to_s
        box_width = (width - 4).clamp(40, width)
        box = ::TTY::Box.frame(
          width: box_width,
          padding: 1,
          title: { top_left: ' Help ' },
          border: :round
        ) { text }

        overlay_lines = box.split("\n")
        start_row = [(height - overlay_lines.size) / 2, 0].max
        left_pad = [(width - box_width) / 2, 0].max

        result = lines.dup
        overlay_lines.each_with_index do |ol, i|
          row = start_row + i
          next if row >= height

          result[row] = (' ' * left_pad) + ol
        end
        result
      rescue StandardError => e
        Legion::Logging.warn("composite_overlay failed: #{e.message}") if defined?(Legion::Logging)
        lines
      end
      # rubocop:enable Metrics/AbcSize

      def write_differential(lines, width)
        lines.each_with_index do |line, row|
          next if @prev_frame[row] == line

          $stdout.print cursor.move_to(0, row)
          $stdout.print line
          plain_len = strip_ansi(line).length
          $stdout.print(' ' * (width - plain_len)) if plain_len < width
        end
        @prev_frame = lines.dup
      end

      def strip_ansi(str)
        str.to_s.gsub(/\e\[[0-9;]*m/, '')
      end

      def cursor
        require 'tty-cursor'
        ::TTY::Cursor
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

      # --- Hotkeys ---

      def setup_hotkeys
        @hotkeys.register(:ctrl_d, 'Toggle dashboard (Ctrl+D)') do
          toggle_dashboard
          :handled
        end
        @hotkeys.register(:ctrl_l, 'Refresh screen (Ctrl+L)') do
          @prev_frame = []
          :handled
        end
        @hotkeys.register(:ctrl_k, 'Command palette (Ctrl+K)') { :command_palette }
        @hotkeys.register(:ctrl_s, 'Session picker (Ctrl+S)') { :session_picker }
      end

      # --- Onboarding ---

      def run_onboarding
        onboarding = Screens::Onboarding.new(self, skip_rain: @skip_rain)
        data = onboarding.activate
        save_config(data)
        @config = load_config
        @credentials = load_credentials
      end

      def save_config(data)
        FileUtils.mkdir_p(@config_dir)
        save_identity(data)
        save_credentials(data)
      end

      # --- LLM Setup ---

      def setup_llm
        boot_legion_subsystems
        @llm_chat = try_settings_llm
      rescue StandardError => e
        Legion::Logging.warn("setup_llm failed: #{e.message}") if defined?(Legion::Logging)
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
        rescue StandardError => e
          Legion::Logging.warn("rescan_environment failed: #{e.message}") if defined?(Legion::Logging)
          nil
        end
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
      def boot_legion_subsystems
        require 'legion/logging'
        Legion::Logging.setup(log_level: 'error', level: 'error', trace: false)

        require 'legion/settings'
        unless Legion::Settings.instance_variable_get(:@loader)
          config_dir = settings_search_path
          Legion::Settings.load(config_dir: config_dir)
        end

        begin
          require 'legion/crypt'
          Legion::Crypt.start unless Legion::Crypt.instance_variable_get(:@started)
          Legion::Settings.resolve_secrets! if Legion::Settings.respond_to?(:resolve_secrets!)
        rescue LoadError => e
          Legion::Logging.debug("legion/crypt not available: #{e.message}") if defined?(Legion::Logging)
          nil
        rescue StandardError => e
          Legion::Logging.warn("crypt/secrets setup failed: #{e.message}") if defined?(Legion::Logging)
          nil
        end

        begin
          require 'legion/llm'
          Legion::Settings.merge_settings(:llm, Legion::LLM::Settings.default)
        rescue LoadError => e
          Legion::Logging.debug("legion/llm not available: #{e.message}") if defined?(Legion::Logging)
          nil
        end
      rescue LoadError => e
        Legion::Logging.debug("legion subsystem load failed: #{e.message}") if defined?(Legion::Logging)
        nil
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength

      def settings_search_path
        [
          '/etc/legionio',
          File.expand_path('~/.legionio/settings'),
          File.expand_path('~/legionio'),
          './settings'
        ].find { |p| Dir.exist?(p) } || @config_dir
      end

      def try_settings_llm
        return nil unless defined?(Legion::LLM)

        Legion::LLM.start unless Legion::LLM.started?
        return nil unless Legion::LLM.started?

        provider = Legion::LLM.settings[:default_provider]
        return nil unless provider

        Legion::LLM.chat(provider: provider, caller: { source: 'tty', screen: 'chat' })
      rescue StandardError => e
        Legion::Logging.warn("try_settings_llm failed: #{e.message}") if defined?(Legion::Logging)
        nil
      end

      # --- Config & Credentials ---

      def safe_config
        cfg = @config
        cfg.is_a?(Hash) ? cfg : {}
      end

      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      def save_identity(data)
        identity = {
          name: data[:name],
          provider: data[:provider],
          created_at: Time.now.iso8601
        }

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

        if data[:github].is_a?(Hash) && data[:github][:username]
          gh = data[:github]
          identity[:github] = {
            username: gh[:username],
            authenticated: gh[:authenticated],
            profile: gh[:profile],
            orgs: gh[:orgs]
          }.compact
        end

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
      rescue ::JSON::ParserError, Errno::ENOENT => e
        Legion::Logging.warn("load_credentials failed: #{e.message}") if defined?(Legion::Logging)
        {}
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
      rescue ::JSON::ParserError, Errno::ENOENT => e
        Legion::Logging.warn("load_config failed: #{e.message}") if defined?(Legion::Logging)
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
