# frozen_string_literal: true

require_relative 'tty/version'
require_relative 'tty/theme'
require_relative 'tty/hotkeys'
require_relative 'tty/screen_manager'
require_relative 'tty/screens/base'
require_relative 'tty/components/digital_rain'
require_relative 'tty/components/input_bar'
require_relative 'tty/components/markdown_view'
require_relative 'tty/components/message_stream'
require_relative 'tty/components/status_bar'
require_relative 'tty/components/tool_panel'
require_relative 'tty/components/wizard_prompt'
require_relative 'tty/background/scanner'
require_relative 'tty/background/github_probe'
require_relative 'tty/screens/onboarding'
require_relative 'tty/screens/chat'
require_relative 'tty/app'

module Legion
  module TTY
    class Error < StandardError; end
  end
end
