# frozen_string_literal: true

require 'tty-markdown'

module Legion
  module TTY
    module Components
      module MarkdownView
        def self.render(text, width: 80)
          ::TTY::Markdown.parse(text, width: width)
        rescue StandardError => e
          Legion::Logging.warn("markdown render failed: #{e.message}") if defined?(Legion::Logging)
          "#{text}\n(markdown render error: #{e.message})"
        end
      end
    end
  end
end
