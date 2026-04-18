# frozen_string_literal: true

require 'legion/logging'

module Legion
  module TTY
    module Components
      module TableView
        class << self
          include Legion::Logging::Helper
        end

        def self.render(headers:, rows:, width: 80)
          require 'tty-table'
          table = ::TTY::Table.new(header: headers, rows: rows)
          table.render(:unicode, width: width, padding: [0, 1]) || ''
        rescue StandardError => e
          log.warn { "table render failed: #{e.message}" }
          "Table render error: #{e.message}"
        end
      end
    end
  end
end
