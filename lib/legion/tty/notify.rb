# frozen_string_literal: true

module Legion
  module TTY
    # Notify — OS-level terminal notification dispatcher with auto-detection.
    #
    # Auto-detects the terminal environment via TERM_PROGRAM and TERM env vars, then
    # dispatches notifications using the most appropriate backend:
    #   - iTerm2:   OSC 9 escape sequence
    #   - kitty:    kitten notify subprocess
    #   - Ghostty:  OSC 99 escape sequence
    #   - Linux:    notify-send subprocess
    #   - macOS:    osascript subprocess
    #   - fallback: terminal bell (\a)
    #
    # Settings integration (read from Legion::Settings when available):
    #   notifications.terminal.enabled  (default: true)
    #   notifications.terminal.backend  (default: 'auto')
    module Notify
      BACKENDS = %w[iterm2 kitty ghostty notify_send osascript bell].freeze

      class << self
        # Send a notification.
        # @param message [String] notification body
        # @param title [String] notification title
        def send(message, title: 'LegionIO')
          return unless enabled?

          backend = configured_backend
          dispatch(backend, message: message, title: title)
        end

        # Detect the current terminal program from environment variables.
        # @return [String] one of: 'iterm2', 'kitty', 'ghostty', 'linux', 'macos', 'unknown'
        def detect_terminal
          term_prog = ::ENV.fetch('TERM_PROGRAM', '').downcase
          term = ::ENV.fetch('TERM', '').downcase

          return 'iterm2'  if term_prog == 'iterm.app'
          return 'kitty'   if term_prog == 'kitty' || term == 'xterm-kitty'
          return 'ghostty' if term_prog == 'ghostty'
          return 'linux'   if linux?
          return 'macos'   if macos?

          'unknown'
        end

        private

        def enabled?
          return true unless defined?(Legion::Settings)

          setting = settings_dig(:notifications, :terminal, :enabled)
          setting.nil? || setting
        end

        def configured_backend
          backend_setting = settings_dig(:notifications, :terminal, :backend)
          return resolve_auto_backend if backend_setting.nil? || backend_setting.to_s == 'auto'

          backend_setting.to_s
        end

        def resolve_auto_backend
          case detect_terminal
          when 'iterm2'  then 'iterm2'
          when 'kitty'   then 'kitty'
          when 'ghostty' then 'ghostty'
          when 'linux'   then 'notify_send'
          when 'macos'   then 'osascript'
          else 'bell'
          end
        end

        def dispatch(backend, message:, title:)
          case backend.to_s
          when 'iterm2'      then notify_iterm2(message: message)
          when 'kitty'       then notify_kitty(message: message, title: title)
          when 'ghostty'     then notify_ghostty(message: message, title: title)
          when 'notify_send' then notify_send(message: message, title: title)
          when 'osascript'   then notify_osascript(message: message, title: title)
          else notify_bell
          end
        rescue StandardError => e
          Legion::Logging.warn("Notify dispatch failed: #{e.message}") if defined?(Legion::Logging)
          notify_bell
        end

        # iTerm2: OSC 9 — "Application-specific notification"
        def notify_iterm2(message:)
          $stdout.print("\e]9;#{message}\a")
          $stdout.flush
        end

        # Kitty: kitten notify subprocess
        def notify_kitty(message:, title:)
          ::Kernel.system('kitten', 'notify', '--title', title, message)
        end

        # Ghostty: OSC 99 (freedesktop desktop notifications via escape sequence)
        def notify_ghostty(message:, title:)
          payload = "i=1:p=body;#{message}\e\\\\#{title}"
          $stdout.print("\e]99;#{payload}\a")
          $stdout.flush
        end

        # Linux: notify-send
        def notify_send(message:, title:)
          ::Kernel.system('notify-send', title, message)
        end

        # macOS: osascript display notification
        def notify_osascript(message:, title:)
          script = "display notification #{message.inspect} with title #{title.inspect}"
          ::Kernel.system('osascript', '-e', script)
        end

        def notify_bell
          $stdout.print("\a")
          $stdout.flush
        end

        def linux?
          !macos? && (::ENV.key?('DISPLAY') || ::ENV.key?('WAYLAND_DISPLAY') || RUBY_PLATFORM.include?('linux'))
        end

        def macos?
          RUBY_PLATFORM.include?('darwin')
        end

        def settings_dig(*keys)
          return nil unless defined?(Legion::Settings)

          first, *rest = keys
          obj = Legion::Settings[first]
          rest.reduce(obj) do |acc, key|
            break nil unless acc.is_a?(Hash)

            acc[key]
          end
        rescue StandardError
          nil
        end
      end
    end
  end
end
