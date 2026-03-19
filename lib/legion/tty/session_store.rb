# frozen_string_literal: true

require 'json'
require 'fileutils'

module Legion
  module TTY
    class SessionStore
      SESSION_DIR = File.expand_path('~/.legionio/sessions')

      def initialize(dir: SESSION_DIR)
        @dir = dir
        FileUtils.mkdir_p(@dir)
      end

      def save(name, messages:, metadata: {})
        data = {
          name: name,
          messages: messages.map { |m| serialize_message(m) },
          metadata: metadata,
          saved_at: Time.now.iso8601,
          version: 1
        }
        File.write(session_path(name), ::JSON.generate(data))
      end

      def load(name)
        path = session_path(name)
        return nil unless File.exist?(path)

        data = ::JSON.parse(File.read(path), symbolize_names: true)
        data[:messages] = data[:messages].map { |m| deserialize_message(m) }
        data
      rescue ::JSON::ParserError
        nil
      end

      def list
        entries = Dir.glob(File.join(@dir, '*.json')).map do |path|
          name = File.basename(path, '.json')
          data = ::JSON.parse(File.read(path), symbolize_names: true)
          { name: name, saved_at: data[:saved_at], message_count: data[:messages]&.size || 0 }
        rescue StandardError
          { name: name, saved_at: nil, message_count: 0 }
        end
        entries.sort_by { |s| s[:saved_at] || '' }.reverse
      end

      def delete(name)
        path = session_path(name)
        FileUtils.rm_f(path)
      end

      def auto_session_name(messages: [])
        first_user = messages.find { |m| m[:role] == :user }
        return "session-#{Time.now.strftime('%H%M%S')}" unless first_user

        words = first_user[:content].to_s.downcase.gsub(/[^a-z0-9\s]/, '').split
        slug = words.first(4).join('-')
        slug = "session-#{Time.now.strftime('%H%M%S')}" if slug.empty?
        slug
      end

      private

      def session_path(name)
        safe = name.gsub(/[^a-zA-Z0-9_-]/, '_')
        File.join(@dir, "#{safe}.json")
      end

      def serialize_message(msg)
        { role: msg[:role].to_s, content: msg[:content], tool_panels: [] }
      end

      def deserialize_message(msg)
        { role: msg[:role].to_sym, content: msg[:content], tool_panels: [] }
      end
    end
  end
end
