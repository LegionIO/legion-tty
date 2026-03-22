# frozen_string_literal: true

module Legion
  module TTY
    module Components
      module TableView
        def self.render(headers:, rows:, width: 80)
          require 'tty-table'
          table = ::TTY::Table.new(header: headers, rows: rows)
          table.render(:unicode, width: width, padding: [0, 1]) || ''
        rescue StandardError => e
          Legion::Logging.warn("table render failed: #{e.message}") if defined?(Legion::Logging)
          "Table render error: #{e.message}"
        end
      end
    end
  end
end
