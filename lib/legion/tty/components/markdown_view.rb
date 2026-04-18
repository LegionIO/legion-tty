# frozen_string_literal: true

require 'tty-markdown'
require 'legion/logging'

module Legion
  module TTY
    module Components
      module MarkdownView
        class << self
          include Legion::Logging::Helper
        end

        def self.render(text, width: 80)
          ::TTY::Markdown.parse(text, width: width)
        rescue StandardError => e
          log.warn { "markdown render failed: #{e.message}" }
          "#{text}\n(markdown render error: #{e.message})"
        end
      end
    end
  end
end
