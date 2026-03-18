# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'legion/tty/background/scanner'

RSpec.describe Legion::TTY::Background::Scanner do
  let(:tmpdir) { Dir.mktmpdir }
  subject(:scanner) { described_class.new(base_dirs: [tmpdir]) }

  after { FileUtils.remove_entry(tmpdir) }

  describe '#initialize' do
    it 'accepts base_dirs' do
      expect(scanner).to be_a(described_class)
    end

    it 'defaults to home directory when no base_dirs given' do
      instance = described_class.new
      expect(instance).to be_a(described_class)
    end
  end

  describe '#scan_services' do
    it 'returns a hash' do
      result = scanner.scan_services
      expect(result).to be_a(Hash)
    end

    it 'includes expected service keys' do
      result = scanner.scan_services
      expect(result.keys).to include(:rabbitmq, :redis, :memcached, :vault, :postgres)
    end

    it 'each service has name, port, and running fields' do
      result = scanner.scan_services
      result.each_value do |svc|
        expect(svc).to include(:name, :port, :running)
        expect(svc[:running]).to be(true).or be(false)
      end
    end

    it 'has correct ports for each service' do
      result = scanner.scan_services
      expect(result[:rabbitmq][:port]).to eq(5672)
      expect(result[:redis][:port]).to eq(6379)
      expect(result[:memcached][:port]).to eq(11_211)
      expect(result[:vault][:port]).to eq(8200)
      expect(result[:postgres][:port]).to eq(5432)
    end
  end

  describe '#scan_git_repos' do
    it 'returns an array' do
      result = scanner.scan_git_repos
      expect(result).to be_an(Array)
    end

    it 'finds a git repo when .git directory exists' do
      repo_dir = File.join(tmpdir, 'myrepo')
      FileUtils.mkdir_p(File.join(repo_dir, '.git'))
      File.write(File.join(repo_dir, 'Gemfile'), "source 'https://rubygems.org'\n")
      result = scanner.scan_git_repos
      paths = result.map { |r| r[:path] }
      expect(paths).to include(repo_dir)
    end

    it 'repo entry has expected keys' do
      repo_dir = File.join(tmpdir, 'testrepo')
      FileUtils.mkdir_p(File.join(repo_dir, '.git'))
      result = scanner.scan_git_repos
      entry = result.find { |r| r[:path] == repo_dir }
      expect(entry).to include(:path, :name, :remote, :branch, :language)
    end
  end

  describe '#scan_shell_history' do
    it 'returns a hash' do
      result = scanner.scan_shell_history
      expect(result).to be_a(Hash)
    end

    it 'returns at most 20 entries' do
      result = scanner.scan_shell_history
      expect(result.size).to be <= 20
    end
  end

  describe '#scan_config_files' do
    it 'returns an array' do
      result = scanner.scan_config_files
      expect(result).to be_an(Array)
    end

    it 'finds Gemfile in base dir' do
      File.write(File.join(tmpdir, 'Gemfile'), "source 'https://rubygems.org'\n")
      result = scanner.scan_config_files
      expect(result).to include(File.join(tmpdir, 'Gemfile'))
    end
  end

  describe '#scan_all' do
    it 'returns a hash with combined results' do
      result = scanner.scan_all
      expect(result).to be_a(Hash)
      expect(result).to include(:services, :repos, :tools, :configs, :dotfiles)
    end

    it 'services key contains service scan results' do
      result = scanner.scan_all
      expect(result[:services]).to be_a(Hash)
    end

    it 'repos key contains array' do
      result = scanner.scan_all
      expect(result[:repos]).to be_an(Array)
    end
  end

  describe '#scan_dotfiles' do
    it 'returns a hash with git, jfrog, and terraform keys' do
      result = scanner.scan_dotfiles
      expect(result).to be_a(Hash)
      expect(result.keys).to contain_exactly(:git, :jfrog, :terraform)
    end
  end

  describe '#scan_gitconfig (via scan_dotfiles)' do
    it 'returns nil when git config is empty' do
      allow(scanner).to receive(:`).and_return('')
      result = scanner.send(:scan_gitconfig)
      expect(result).to be_nil
    end

    it 'returns name and email when git config exists' do
      allow(scanner).to receive(:`).with(/user\.name/).and_return("Jane Doe\n")
      allow(scanner).to receive(:`).with(/user\.email/).and_return("jane@example.com\n")
      allow(scanner).to receive(:`).with(/signingkey/).and_return("\n")
      result = scanner.send(:scan_gitconfig)
      expect(result).to eq({ name: 'Jane Doe', email: 'jane@example.com' })
    end

    it 'includes signing_key when present' do
      allow(scanner).to receive(:`).with(/user\.name/).and_return("Jane Doe\n")
      allow(scanner).to receive(:`).with(/user\.email/).and_return("jane@example.com\n")
      allow(scanner).to receive(:`).with(/signingkey/).and_return("ABC123\n")
      result = scanner.send(:scan_gitconfig)
      expect(result[:signing_key]).to eq('ABC123')
    end
  end

  describe '#scan_jfrog (via scan_dotfiles)' do
    it 'returns nil when config file does not exist' do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(File.expand_path('~/.jfrog/jfrog-cli.conf.v6')).and_return(false)
      result = scanner.send(:scan_jfrog)
      expect(result).to be_nil
    end

    it 'parses jfrog config and returns server info' do
      config = { servers: [{ serverId: 'myserver', url: 'https://example.jfrog.io', user: 'jane' }] }
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(File.expand_path('~/.jfrog/jfrog-cli.conf.v6')).and_return(true)
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with(File.expand_path('~/.jfrog/jfrog-cli.conf.v6')).and_return(config.to_json)
      result = scanner.send(:scan_jfrog)
      expect(result).to eq([{ server_id: 'myserver', url: 'https://example.jfrog.io', user: 'jane' }])
    end
  end

  describe '#scan_terraform (via scan_dotfiles)' do
    it 'returns nil when credentials file does not exist' do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(File.expand_path('~/.terraform.d/credentials.tfrc.json')).and_return(false)
      result = scanner.send(:scan_terraform)
      expect(result).to be_nil
    end

    it 'parses terraform credentials and returns host list' do
      creds = { credentials: { 'app.terraform.io' => { token: 'abc' }, 'tfe.example.com' => { token: 'xyz' } } }
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(File.expand_path('~/.terraform.d/credentials.tfrc.json')).and_return(true)
      allow(File).to receive(:read).and_call_original
      tf_creds_path = File.expand_path('~/.terraform.d/credentials.tfrc.json')
      allow(File).to receive(:read).with(tf_creds_path).and_return(creds.to_json)
      result = scanner.send(:scan_terraform)
      expect(result[:hosts]).to contain_exactly('app.terraform.io', 'tfe.example.com')
    end
  end

  describe '#run_async' do
    it 'returns a Thread' do
      queue = Queue.new
      thread = scanner.run_async(queue)
      expect(thread).to be_a(Thread)
      thread.join(5)
    end

    it 'pushes a scan_complete event to the queue' do
      queue = Queue.new
      thread = scanner.run_async(queue)
      thread.join(10)
      event = queue.pop(true)
      expect(event[:type]).to eq(:scan_complete)
      expect(event[:data]).to be_a(Hash)
    end
  end
end
