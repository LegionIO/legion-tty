# frozen_string_literal: true

require 'socket'
require 'fileutils'

module Legion
  module TTY
    module Background
      # rubocop:disable Metrics/ClassLength
      class Scanner
        MAX_DEPTH = 3

        SERVICES = {
          rabbitmq: 5672,
          redis: 6379,
          memcached: 11_211,
          vault: 8200,
          postgres: 5432
        }.freeze

        CONFIG_FILES = %w[.env Gemfile package.json Dockerfile].freeze

        LANGUAGE_MAP = {
          '.rb' => 'Ruby',
          '.py' => 'Python',
          '.js' => 'JavaScript',
          '.ts' => 'TypeScript',
          '.go' => 'Go',
          '.java' => 'Java',
          '.rs' => 'Rust',
          '.tf' => 'Terraform',
          '.sh' => 'Shell'
        }.freeze

        def initialize(base_dirs: nil, logger: nil)
          @base_dirs = base_dirs || [File.expand_path('~')]
          @log = logger
        end

        def scan_services
          SERVICES.each_with_object({}) do |(name, port), result|
            result[name] = { name: name.to_s, port: port, running: port_open?('127.0.0.1', port) }
          end
        end

        def scan_git_repos
          @base_dirs.flat_map { |base| collect_repos(base) }
        end

        def scan_shell_history
          lines = read_history_lines
          tally_commands(lines).sort_by { |_, v| -v }.first(20).to_h
        end

        def scan_config_files
          @base_dirs.flat_map do |base|
            CONFIG_FILES.map { |name| File.join(base, name) }.select { |p| File.exist?(p) }
          end
        end

        def scan_all
          { services: scan_services, repos: scan_git_repos, tools: scan_shell_history,
            configs: scan_config_files, dotfiles: scan_dotfiles }
        end

        def scan_dotfiles
          {
            git: scan_gitconfig,
            jfrog: scan_jfrog,
            terraform: scan_terraform
          }
        end

        def run_async(queue)
          Thread.new do
            @log&.log('scanner', "starting scan of #{@base_dirs.join(', ')}")
            t0 = Time.now
            data = scan_all
            elapsed = ((Time.now - t0) * 1000).round
            @log&.log('scanner', "scan complete in #{elapsed}ms")
            queue.push({ type: :scan_complete, data: data })
          rescue StandardError => e
            @log&.log('scanner', "ERROR: #{e.class}: #{e.message}")
            queue.push({ type: :scan_error, error: e.message })
          end
        end

        private

        def port_open?(host, port)
          ::Socket.tcp(host, port, connect_timeout: 1) { true }
        rescue StandardError
          false
        end

        def collect_repos(base, depth = 0)
          return [] unless File.directory?(base)
          return [build_repo_entry(base)] if File.directory?(File.join(base, '.git'))
          return [] if depth >= MAX_DEPTH

          Dir.children(base).each_with_object([]) do |child, acc|
            next if child.start_with?('.')

            child_path = File.join(base, child)
            acc.concat(collect_repos(child_path, depth + 1)) if File.directory?(child_path)
          rescue StandardError
            next
          end
        rescue StandardError
          []
        end

        def build_repo_entry(path)
          { path: path, name: File.basename(path), remote: git_remote(path),
            branch: git_branch(path), language: detect_language(path) }
        end

        def git_remote(path)
          out = `git -C #{path.shellescape} remote get-url origin 2>/dev/null`.strip
          out.empty? ? nil : out
        rescue StandardError
          nil
        end

        def git_branch(path)
          out = `git -C #{path.shellescape} rev-parse --abbrev-ref HEAD 2>/dev/null`.strip
          out.empty? ? nil : out
        rescue StandardError
          nil
        end

        def detect_language(path)
          ext_counts = Hash.new(0)
          Dir.glob(File.join(path, '**', '*')).each do |f|
            ext = File.extname(f)
            ext_counts[ext] += 1 if File.file?(f) && !ext.empty?
          end
          LANGUAGE_MAP[ext_counts.max_by { |_, v| v }&.first]
        end

        def read_history_lines
          %w[~/.zsh_history ~/.bash_history].flat_map do |path|
            full = File.expand_path(path)
            next [] unless File.exist?(full)

            File.readlines(full, encoding: 'utf-8', chomp: true).last(500)
          rescue StandardError
            []
          end
        end

        def tally_commands(lines)
          lines.each_with_object(Hash.new(0)) do |line, counts|
            cmd = extract_command(line)
            counts[cmd] += 1 if cmd && !cmd.empty?
          end
        end

        def extract_command(line)
          line.sub(/^: \d+:\d+;/, '').split.first
        end

        def scan_gitconfig
          name = `git config --global user.name 2>/dev/null`.strip
          email = `git config --global user.email 2>/dev/null`.strip
          signing_key = `git config --global user.signingkey 2>/dev/null`.strip
          return nil if name.empty? && email.empty?

          result = { name: name.empty? ? nil : name, email: email.empty? ? nil : email }
          result[:signing_key] = signing_key unless signing_key.empty?
          result
        rescue StandardError
          nil
        end

        def scan_jfrog
          config_path = File.expand_path('~/.jfrog/jfrog-cli.conf.v6')
          return nil unless File.exist?(config_path)

          require 'json'
          data = ::JSON.parse(File.read(config_path), symbolize_names: true)
          servers = data[:servers]
          return nil unless servers.is_a?(Array) && !servers.empty?

          servers.map do |s|
            { server_id: s[:serverId], url: s[:url], user: s[:user] }
          end
        rescue StandardError
          nil
        end

        def scan_terraform
          creds_path = File.expand_path('~/.terraform.d/credentials.tfrc.json')
          return nil unless File.exist?(creds_path)

          require 'json'
          data = ::JSON.parse(File.read(creds_path), symbolize_names: true)
          hosts = data[:credentials]&.keys || []
          return nil if hosts.empty?

          { hosts: hosts.map(&:to_s) }
        rescue StandardError
          nil
        end
      end
      # rubocop:enable Metrics/ClassLength
    end
  end
end
