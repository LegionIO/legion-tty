# frozen_string_literal: true

require 'fileutils'

module Legion
  module TTY
    class BootLogger
      LOG_DIR = File.expand_path('~/.legionio/logs')
      LOG_FILE = File.join(LOG_DIR, 'tty-boot.log')

      def initialize(path: LOG_FILE)
        @path = path
        FileUtils.mkdir_p(File.dirname(@path))
        File.write(@path, '')
        log('boot', 'legion-tty boot logger started')
      end

      def log(source, message)
        ts = Time.now.strftime('%H:%M:%S.%L')
        line = "[#{ts}] [#{source}] #{message}\n"
        File.open(@path, 'a') { |f| f.write(line) }
      end

      def log_hash(source, label, hash)
        log(source, "#{label}:")
        hash.each do |k, v|
          log(source, "  #{k}: #{v.inspect}")
        end
      end

      attr_reader :path
    end
  end
end
