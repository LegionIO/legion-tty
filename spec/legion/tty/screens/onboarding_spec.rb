# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/onboarding'

RSpec.describe Legion::TTY::Screens::Onboarding do
  let(:app) { double('app') }
  let(:output) { StringIO.new }
  let(:mock_wizard) do
    instance_double(Legion::TTY::Components::WizardPrompt,
                    ask_name: 'Matt',
                    select_provider: 'claude',
                    ask_api_key: 'sk-test',
                    display_provider_results: nil,
                    select_default_provider: 'claude',
                    confirm: true,
                    ask_with_default: 'jdoe',
                    ask_secret: 'password123')
  end

  subject(:screen) { described_class.new(app, wizard: mock_wizard, output: output, skip_rain: true) }

  describe '#initialize' do
    it 'stores the app reference' do
      expect(screen.app).to eq(app)
    end

    it 'accepts a wizard override' do
      expect(screen).to be_a(described_class)
    end
  end

  describe '#run_wizard' do
    before do
      allow(screen).to receive(:sleep)
      allow(screen).to receive(:typed_output)
      screen.instance_variable_get(:@llm_queue).push({ type: :llm_probe_complete, data: { providers: [] } })
    end

    it 'returns a hash with name' do
      result = screen.run_wizard
      expect(result[:name]).to eq('Matt')
    end

    it 'returns a hash with provider key' do
      result = screen.run_wizard
      expect(result).to have_key(:provider)
    end

    it 'returns a hash with providers array' do
      result = screen.run_wizard
      expect(result[:providers]).to be_an(Array)
    end

    it 'calls ask_name on the wizard' do
      expect(mock_wizard).to receive(:ask_name).and_return('Matt')
      screen.run_wizard
    end

    it 'calls display_provider_results on the wizard' do
      expect(mock_wizard).to receive(:display_provider_results).with([])
      screen.run_wizard
    end

    it 'calls select_default_provider on the wizard when no working providers' do
      allow(mock_wizard).to receive(:select_default_provider).and_return(nil)
      screen.run_wizard
    end
  end

  describe '#build_summary' do
    before do
      allow(screen).to receive(:legionio_running?).and_return(false)
    end

    it 'includes the user name' do
      summary = screen.build_summary(name: 'Matt', scan_data: nil, github_data: nil)
      expect(summary).to include('Matt')
    end

    it 'handles nil github_data gracefully' do
      expect do
        screen.build_summary(name: 'Matt', scan_data: nil, github_data: nil)
      end.not_to raise_error
    end

    it 'includes github info when available' do
      github_data = { username: 'Esity', profile: { name: 'Matthew', repos: 42 } }
      summary = screen.build_summary(name: 'Matt', scan_data: nil, github_data: github_data)
      expect(summary).to include('Esity')
    end

    it 'handles nil scan_data gracefully' do
      expect do
        screen.build_summary(name: 'Matt', scan_data: nil, github_data: nil)
      end.not_to raise_error
    end

    it 'returns a string' do
      result = screen.build_summary(name: 'Matt', scan_data: {}, github_data: nil)
      expect(result).to be_a(String)
    end
  end

  describe '#activate' do
    before do
      allow(screen).to receive(:sleep)
      allow(screen).to receive(:typed_output)
      screen.instance_variable_get(:@llm_queue).push({ type: :llm_probe_complete, data: { providers: [] } })
    end

    it 'returns a config hash with name and provider' do
      allow(screen).to receive(:run_rain)
      allow(screen).to receive(:run_intro)
      allow(screen).to receive(:start_background_threads)
      allow(screen).to receive(:collect_background_results).and_return([nil, nil])
      allow(screen).to receive(:collect_bootstrap_result)
      allow(screen).to receive(:run_cache_awakening)
      allow(screen).to receive(:run_gaia_awakening)
      allow(screen).to receive(:run_extension_detection)
      allow(screen).to receive(:run_reveal).and_return(true)
      result = screen.activate
      expect(result).to include(:name, :provider)
    end

    it 'skips rain when skip_rain is true' do
      allow(screen).to receive(:run_intro)
      allow(screen).to receive(:start_background_threads)
      allow(screen).to receive(:collect_bootstrap_result)
      allow(screen).to receive(:collect_background_results).and_return([nil, nil])
      allow(screen).to receive(:run_cache_awakening)
      allow(screen).to receive(:run_gaia_awakening)
      allow(screen).to receive(:run_extension_detection)
      allow(screen).to receive(:run_reveal).and_return(true)
      expect(screen).not_to receive(:run_rain)
      screen.activate
    end
  end

  describe '#collect_background_results' do
    it 'returns an array of two elements' do
      allow(screen).to receive(:start_background_threads)
      scan_queue = Queue.new
      github_queue = Queue.new
      scan_queue.push({ type: :scan_complete, data: { services: {}, repos: [] } })
      github_queue.push({ type: :github_probe_complete, data: { username: nil } })
      screen.instance_variable_set(:@scan_queue, scan_queue)
      screen.instance_variable_set(:@github_queue, github_queue)
      probe = Legion::TTY::Background::GitHubProbe.new
      allow(probe).to receive(:run_async) { github_queue }
      screen.instance_variable_set(:@github_probe, probe)
      result = screen.collect_background_results
      expect(result).to be_an(Array)
      expect(result.size).to eq(2)
    end
  end

  describe '#vault_clusters_configured?' do
    let(:settings_stub) do
      mod = Module.new
      mod.define_singleton_method(:dig) { |*_args| nil }
      mod
    end

    it 'returns false when Legion::Settings is not defined' do
      hide_const('Legion::Settings') if defined?(Legion::Settings)
      expect(screen.send(:vault_clusters_configured?)).to be(false)
    end

    it 'returns false when clusters is nil' do
      stub_const('Legion::Settings', settings_stub)
      allow(Legion::Settings).to receive(:dig).with(:crypt, :vault, :clusters).and_return(nil)
      expect(screen.send(:vault_clusters_configured?)).to be(false)
    end

    it 'returns false when clusters is an empty hash' do
      stub_const('Legion::Settings', settings_stub)
      allow(Legion::Settings).to receive(:dig).with(:crypt, :vault, :clusters).and_return({})
      expect(screen.send(:vault_clusters_configured?)).to be(false)
    end

    it 'returns true when clusters has entries' do
      stub_const('Legion::Settings', settings_stub)
      allow(Legion::Settings).to receive(:dig).with(:crypt, :vault, :clusters)
                                              .and_return({ primary: { address: 'https://vault.example.com' } })
      expect(screen.send(:vault_clusters_configured?)).to be(true)
    end

    it 'returns false when an error is raised' do
      stub_const('Legion::Settings', settings_stub)
      allow(Legion::Settings).to receive(:dig).and_raise(StandardError, 'settings error')
      expect(screen.send(:vault_clusters_configured?)).to be(false)
    end
  end

  describe '#default_vault_username' do
    it 'returns the kerberos username when available' do
      screen.instance_variable_set(:@kerberos_identity, { username: 'jdoe', first_name: 'Jane' })
      expect(screen.send(:default_vault_username)).to eq('jdoe')
    end

    it 'falls back to ENV USER when no kerberos identity' do
      screen.instance_variable_set(:@kerberos_identity, nil)
      allow(ENV).to receive(:fetch).with('USER', 'unknown').and_return('testuser')
      expect(screen.send(:default_vault_username)).to eq('testuser')
    end

    it 'falls back to ENV USER when kerberos identity has no username' do
      screen.instance_variable_set(:@kerberos_identity, { first_name: 'Jane' })
      allow(ENV).to receive(:fetch).with('USER', 'unknown').and_return('testuser')
      expect(screen.send(:default_vault_username)).to eq('testuser')
    end
  end

  describe '#run_vault_auth' do
    it 'skips entirely when no vault clusters are configured' do
      allow(screen).to receive(:vault_clusters_configured?).and_return(false)
      expect(mock_wizard).not_to receive(:confirm)
      screen.send(:run_vault_auth)
    end

    it 'prompts the user when clusters are configured and user confirms' do
      allow(screen).to receive(:vault_clusters_configured?).and_return(true)
      allow(screen).to receive(:vault_cluster_count).and_return(1)
      allow(screen).to receive(:default_vault_username).and_return('jdoe')
      allow(screen).to receive(:typed_output)
      allow(mock_wizard).to receive(:confirm).with('Connect now?').and_return(true)
      allow(mock_wizard).to receive(:ask_with_default).with('Username:', 'jdoe').and_return('jdoe')
      allow(mock_wizard).to receive(:ask_secret).with('Password:').and_return('s3cr3t')
      allow(screen).to receive(:perform_vault_auth).and_return({})
      allow(screen).to receive(:display_vault_results)
      screen.send(:run_vault_auth)
      expect(mock_wizard).to have_received(:confirm).with('Connect now?')
    end

    it 'skips auth when user declines to connect' do
      allow(screen).to receive(:vault_clusters_configured?).and_return(true)
      allow(screen).to receive(:vault_cluster_count).and_return(2)
      allow(screen).to receive(:typed_output)
      allow(mock_wizard).to receive(:confirm).with('Connect now?').and_return(false)
      expect(mock_wizard).not_to receive(:ask_secret)
      screen.send(:run_vault_auth)
    end

    it 'skips auth when password is empty' do
      allow(screen).to receive(:vault_clusters_configured?).and_return(true)
      allow(screen).to receive(:vault_cluster_count).and_return(1)
      allow(screen).to receive(:default_vault_username).and_return('jdoe')
      allow(screen).to receive(:typed_output)
      allow(mock_wizard).to receive(:confirm).with('Connect now?').and_return(true)
      allow(mock_wizard).to receive(:ask_with_default).and_return('jdoe')
      allow(mock_wizard).to receive(:ask_secret).and_return('')
      expect(screen).not_to receive(:perform_vault_auth)
      screen.send(:run_vault_auth)
    end
  end

  describe '#vault_summary_lines' do
    it 'returns empty array when vault_results is nil' do
      screen.instance_variable_set(:@vault_results, nil)
      expect(screen.send(:vault_summary_lines)).to eq([])
    end

    it 'returns empty array when vault_results is an empty hash' do
      screen.instance_variable_set(:@vault_results, {})
      expect(screen.send(:vault_summary_lines)).to eq([])
    end

    it 'returns formatted lines when a cluster connected successfully' do
      screen.instance_variable_set(:@vault_results, {
                                     primary: { token: 'abc123', policies: %w[default admin] }
                                   })
      lines = screen.send(:vault_summary_lines)
      expect(lines).to include('Vault:')
      expect(lines.any? { |l| l.include?('primary') && l.include?('connected') }).to be(true)
    end

    it 'returns formatted lines when a cluster failed' do
      screen.instance_variable_set(:@vault_results, {
                                     primary: { error: 'connection refused' }
                                   })
      lines = screen.send(:vault_summary_lines)
      expect(lines).to include('Vault:')
      expect(lines.any? { |l| l.include?('primary') && l.include?('failed') }).to be(true)
    end

    it 'includes both connected and failed clusters' do
      screen.instance_variable_set(:@vault_results, {
                                     primary: { token: 'tok1', policies: [] },
                                     secondary: { error: 'timeout' }
                                   })
      lines = screen.send(:vault_summary_lines)
      expect(lines.any? { |l| l.include?('primary') }).to be(true)
      expect(lines.any? { |l| l.include?('secondary') }).to be(true)
    end
  end

  describe '#build_summary with vault results' do
    before do
      allow(screen).to receive(:legionio_running?).and_return(false)
    end

    it 'includes vault section when vault_results are present' do
      screen.instance_variable_set(:@vault_results, {
                                     primary: { token: 'tok1', policies: ['default'] }
                                   })
      summary = screen.build_summary(name: 'Jane', scan_data: nil, github_data: nil)
      expect(summary).to include('Vault:')
    end

    it 'omits vault section when vault_results is nil' do
      screen.instance_variable_set(:@vault_results, nil)
      summary = screen.build_summary(name: 'Jane', scan_data: nil, github_data: nil)
      expect(summary).not_to include('Vault:')
    end
  end

  describe '#run_cache_awakening' do
    before do
      allow(screen).to receive(:typed_output)
      allow(screen).to receive(:sleep)
    end

    it 'skips when scan_data is nil' do
      expect(screen).not_to receive(:typed_output)
      screen.run_cache_awakening(nil)
    end

    it 'shows extending neural pathways when memcached is running' do
      scan_data = { services: { memcached: { running: true, name: 'memcached' } } }
      expect(screen).to receive(:typed_output).with('... extending neural pathways...')
      expect(screen).to receive(:typed_output).with('Additional memory online.')
      screen.run_cache_awakening(scan_data)
    end

    it 'shows extending neural pathways when redis is running' do
      scan_data = { services: { redis: { running: true, name: 'redis' } } }
      expect(screen).to receive(:typed_output).with('... extending neural pathways...')
      expect(screen).to receive(:typed_output).with('Additional memory online.')
      screen.run_cache_awakening(scan_data)
    end

    it 'shows no extended memory and asks when neither is running' do
      scan_data = { services: { redis: { running: false }, memcached: { running: false } } }
      allow(mock_wizard).to receive(:confirm).with('Shall I activate a memory cache?').and_return(false)
      expect(screen).to receive(:typed_output).with('No extended memory detected.')
      screen.run_cache_awakening(scan_data)
    end

    it 'skips gracefully when services hash is missing from scan_data' do
      scan_data = { repos: [] }
      expect(screen).not_to receive(:typed_output)
      screen.run_cache_awakening(scan_data)
    end

    it 'attempts to start cache when user confirms and binary is detected' do
      scan_data = { services: { redis: { running: false }, memcached: { running: false } } }
      allow(mock_wizard).to receive(:confirm).with('Shall I activate a memory cache?').and_return(true)
      allow(screen).to receive(:detect_cache_binary).and_return(:memcached)
      allow(screen).to receive(:start_cache_service).with('memcached').and_return(true)
      expect(screen).to receive(:typed_output).with('Memory cache activated. Neural capacity expanded.')
      screen.run_cache_awakening(scan_data)
    end

    it 'shows install hint when no binary is detected' do
      scan_data = { services: { redis: { running: false }, memcached: { running: false } } }
      allow(mock_wizard).to receive(:confirm).with('Shall I activate a memory cache?').and_return(true)
      allow(screen).to receive(:detect_cache_binary).and_return(nil)
      expect(screen).to receive(:typed_output).with('No cache service found. Install with: brew install memcached')
      screen.run_cache_awakening(scan_data)
    end
  end

  describe '#run_gaia_awakening' do
    before do
      allow(screen).to receive(:typed_output)
      allow(screen).to receive(:sleep)
      allow(screen).to receive(:offer_gaia_gems)
    end

    it 'shows GAIA is awake when daemon is running' do
      allow(screen).to receive(:legionio_running?).and_return(true)
      expect(screen).to receive(:typed_output).with('GAIA is awake.')
      expect(screen).to receive(:typed_output).with('Heuristic mesh: nominal.')
      expect(screen).to receive(:typed_output).with('Cognitive threads synchronized.')
      screen.run_gaia_awakening
    end

    it 'calls offer_gaia_gems when daemon is already running' do
      allow(screen).to receive(:legionio_running?).and_return(true)
      expect(screen).to receive(:offer_gaia_gems)
      screen.run_gaia_awakening
    end

    it 'shows GAIA is dormant when daemon is not running and user declines' do
      allow(screen).to receive(:legionio_running?).and_return(false)
      allow(mock_wizard).to receive(:confirm).with('Shall I wake her?').and_return(false)
      expect(screen).to receive(:typed_output).with('Scanning for active cognition threads...')
      expect(screen).to receive(:typed_output).with('GAIA is dormant.')
      screen.run_gaia_awakening
    end

    it 'does not call offer_gaia_gems when user declines to wake GAIA' do
      allow(screen).to receive(:legionio_running?).and_return(false)
      allow(mock_wizard).to receive(:confirm).with('Shall I wake her?').and_return(false)
      expect(screen).not_to receive(:offer_gaia_gems)
      screen.run_gaia_awakening
    end

    it 'attempts to start daemon when user confirms' do
      allow(screen).to receive(:legionio_running?).and_return(false)
      allow(mock_wizard).to receive(:confirm).with('Shall I wake her?').and_return(true)
      allow(screen).to receive(:start_legionio_daemon).and_return(true)
      expect(screen).to receive(:typed_output).with('GAIA online. All systems nominal.')
      screen.run_gaia_awakening
    end

    it 'calls offer_gaia_gems after successfully starting the daemon' do
      allow(screen).to receive(:legionio_running?).and_return(false)
      allow(mock_wizard).to receive(:confirm).with('Shall I wake her?').and_return(true)
      allow(screen).to receive(:start_legionio_daemon).and_return(true)
      expect(screen).to receive(:offer_gaia_gems)
      screen.run_gaia_awakening
    end

    it 'does not call offer_gaia_gems when daemon start fails' do
      allow(screen).to receive(:legionio_running?).and_return(false)
      allow(mock_wizard).to receive(:confirm).with('Shall I wake her?').and_return(true)
      allow(screen).to receive(:start_legionio_daemon).and_return(false)
      expect(screen).not_to receive(:offer_gaia_gems)
      screen.run_gaia_awakening
    end

    it 'shows failure message when daemon start fails' do
      allow(screen).to receive(:legionio_running?).and_return(false)
      allow(mock_wizard).to receive(:confirm).with('Shall I wake her?').and_return(true)
      allow(screen).to receive(:start_legionio_daemon).and_return(false)
      expect(screen).to receive(:typed_output).with("Could not start daemon. Run 'legionio start' manually.")
      screen.run_gaia_awakening
    end
  end

  describe '#wake_gaia_daemon' do
    before do
      allow(screen).to receive(:typed_output)
      allow(screen).to receive(:sleep)
    end

    it 'returns nil when user declines' do
      allow(mock_wizard).to receive(:confirm).with('Shall I wake her?').and_return(false)
      expect(screen.send(:wake_gaia_daemon)).to be_nil
    end

    it 'returns true when daemon starts successfully' do
      allow(mock_wizard).to receive(:confirm).with('Shall I wake her?').and_return(true)
      allow(screen).to receive(:start_legionio_daemon).and_return(true)
      expect(screen.send(:wake_gaia_daemon)).to be(true)
    end

    it 'returns false when daemon fails to start' do
      allow(mock_wizard).to receive(:confirm).with('Shall I wake her?').and_return(true)
      allow(screen).to receive(:start_legionio_daemon).and_return(false)
      expect(screen.send(:wake_gaia_daemon)).to be(false)
    end
  end

  describe '#offer_gaia_gems' do
    before do
      allow(screen).to receive(:typed_output)
      allow(screen).to receive(:sleep)
    end

    it 'does nothing when all GAIA gems are already installed' do
      allow(Gem::Specification).to receive(:find_by_name).and_return(double('spec'))
      expect(mock_wizard).not_to receive(:confirm)
      screen.send(:offer_gaia_gems)
    end

    it 'shows count and asks when some gems are missing' do
      allow(Gem::Specification).to receive(:find_by_name).and_raise(Gem::LoadError)
      allow(mock_wizard).to receive(:confirm).with('Install cognitive extensions?').and_return(false)
      expect(screen).to receive(:typed_output).with(
        "#{Legion::TTY::Screens::Onboarding::GAIA_GEMS.size} cognitive extensions not installed."
      )
      screen.send(:offer_gaia_gems)
    end

    it 'installs missing gems when user confirms' do
      allow(Gem::Specification).to receive(:find_by_name).and_raise(Gem::LoadError)
      allow(mock_wizard).to receive(:confirm).with('Install cognitive extensions?').and_return(true)
      allow(Gem).to receive(:install)
      expect(screen).to receive(:typed_output).with('Cognitive extensions installed.')
      screen.send(:offer_gaia_gems)
    end

    it 'skips install when user declines' do
      allow(Gem::Specification).to receive(:find_by_name).and_raise(Gem::LoadError)
      allow(mock_wizard).to receive(:confirm).with('Install cognitive extensions?').and_return(false)
      expect(Gem).not_to receive(:install)
      screen.send(:offer_gaia_gems)
    end

    it 'handles install errors gracefully' do
      allow(Gem::Specification).to receive(:find_by_name).and_raise(Gem::LoadError)
      allow(mock_wizard).to receive(:confirm).with('Install cognitive extensions?').and_return(true)
      allow(Gem).to receive(:install).and_raise(StandardError, 'network error')
      expect { screen.send(:offer_gaia_gems) }.not_to raise_error
    end

    it 'reports singular noun when only one gem is missing' do
      missing_gem = Legion::TTY::Screens::Onboarding::GAIA_GEMS.first
      allow(Gem::Specification).to receive(:find_by_name) do |name|
        raise Gem::LoadError if name == missing_gem

        double('spec')
      end
      allow(mock_wizard).to receive(:confirm).with('Install cognitive extensions?').and_return(false)
      expect(screen).to receive(:typed_output).with('1 cognitive extension not installed.')
      screen.send(:offer_gaia_gems)
    end
  end

  describe '#select_provider_default' do
    before do
      allow(screen).to receive(:typed_output)
      allow(screen).to receive(:sleep)
    end

    it 'selects from :ok providers when available' do
      providers = [
        { name: 'claude', model: 'claude-3', status: :ok, latency_ms: 200 },
        { name: 'openai', model: 'gpt-4', status: :configured, latency_ms: 100 }
      ]
      expect(mock_wizard).to receive(:select_default_provider).with([providers.first]).and_return('claude')
      result = screen.send(:select_provider_default, providers)
      expect(result).to eq('claude')
    end

    it 'falls back to :configured providers when no :ok providers exist' do
      providers = [
        { name: 'foundry', model: 'gpt-4o', status: :configured, latency_ms: 50 }
      ]
      expect(mock_wizard).to receive(:select_default_provider).with(providers).and_return('foundry')
      result = screen.send(:select_provider_default, providers)
      expect(result).to eq('foundry')
    end

    it 'returns nil and shows message when no providers at all' do
      expect(screen).to receive(:typed_output).with(
        'No AI providers detected. Configure one in ~/.legionio/settings/llm.json'
      )
      result = screen.send(:select_provider_default, [])
      expect(result).to be_nil
    end

    it 'returns nil when only :error providers exist' do
      providers = [{ name: 'openai', model: 'gpt-4', status: :error, latency_ms: 50 }]
      expect(screen).to receive(:typed_output).with(
        'No AI providers detected. Configure one in ~/.legionio/settings/llm.json'
      )
      result = screen.send(:select_provider_default, providers)
      expect(result).to be_nil
    end
  end

  describe '#detect_cache_binary' do
    it 'returns :memcached when memcached is available' do
      allow(screen).to receive(:system).with('which memcached > /dev/null 2>&1').and_return(true)
      expect(screen.send(:detect_cache_binary)).to eq(:memcached)
    end

    it 'returns :redis as fallback when only redis-server is available' do
      allow(screen).to receive(:system).with('which memcached > /dev/null 2>&1').and_return(false)
      allow(screen).to receive(:system).with('which redis-server > /dev/null 2>&1').and_return(true)
      expect(screen.send(:detect_cache_binary)).to eq(:redis)
    end

    it 'returns nil when neither is installed' do
      allow(screen).to receive(:system).with('which memcached > /dev/null 2>&1').and_return(false)
      allow(screen).to receive(:system).with('which redis-server > /dev/null 2>&1').and_return(false)
      expect(screen.send(:detect_cache_binary)).to be_nil
    end
  end

  describe '#legionio_running?' do
    it 'returns false when no PID file exists and pgrep returns false' do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(File.expand_path('~/.legionio/legion.pid')).and_return(false)
      allow(File).to receive(:exist?).with('/tmp/legionio.pid').and_return(false)
      allow(screen).to receive(:system).with('pgrep -x legionio > /dev/null 2>&1').and_return(false)
      expect(screen.send(:legionio_running?)).to be(false)
    end

    it 'returns true when pgrep finds the process' do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(File.expand_path('~/.legionio/legion.pid')).and_return(false)
      allow(File).to receive(:exist?).with('/tmp/legionio.pid').and_return(false)
      allow(screen).to receive(:system).with('pgrep -x legionio > /dev/null 2>&1').and_return(true)
      expect(screen.send(:legionio_running?)).to be(true)
    end
  end

  describe '#cache_summary_lines' do
    it 'returns memcached online line when memcached is running' do
      scan_data = { services: { memcached: { running: true } } }
      allow(screen).to receive(:legionio_running?).and_return(false)
      lines = screen.send(:cache_summary_lines, scan_data)
      expect(lines).to include('Memory: memcached online')
    end

    it 'returns redis online line when redis is running' do
      scan_data = { services: { redis: { running: true } } }
      allow(screen).to receive(:legionio_running?).and_return(false)
      lines = screen.send(:cache_summary_lines, scan_data)
      expect(lines).to include('Memory: redis online')
    end

    it 'returns no cache running line when neither is running' do
      scan_data = { services: { redis: { running: false }, memcached: { running: false } } }
      lines = screen.send(:cache_summary_lines, scan_data)
      expect(lines).to include('Memory: no cache service running')
    end

    it 'returns empty array when scan_data is nil' do
      expect(screen.send(:cache_summary_lines, nil)).to eq([])
    end

    it 'returns empty array when services key is missing' do
      expect(screen.send(:cache_summary_lines, { repos: [] })).to eq([])
    end
  end

  describe '#gaia_summary_lines' do
    it 'returns GAIA online when running' do
      allow(screen).to receive(:legionio_running?).and_return(true)
      lines = screen.send(:gaia_summary_lines)
      expect(lines).to include('GAIA: online')
    end

    it 'returns GAIA dormant when not running' do
      allow(screen).to receive(:legionio_running?).and_return(false)
      lines = screen.send(:gaia_summary_lines)
      expect(lines).to include('GAIA: dormant')
    end
  end

  describe '#bootstrap_summary_lines' do
    it 'returns empty array when bootstrap_data is nil' do
      screen.instance_variable_set(:@bootstrap_data, nil)
      expect(screen.send(:bootstrap_summary_lines)).to eq([])
    end

    it 'returns empty array when sections is empty' do
      screen.instance_variable_set(:@bootstrap_data, { sections: [], files: [] })
      expect(screen.send(:bootstrap_summary_lines)).to eq([])
    end

    it 'returns formatted line when sections are present' do
      screen.instance_variable_set(:@bootstrap_data, { sections: %w[crypt transport cache], files: [] })
      lines = screen.send(:bootstrap_summary_lines)
      expect(lines).to include('Bootstrap config: crypt, transport, cache')
    end
  end

  describe '#collect_bootstrap_result' do
    it 'sets bootstrap_data when queue has data' do
      queue = Queue.new
      queue.push({ type: :bootstrap_complete, data: { files: ['crypt.json'], sections: ['crypt'] } })
      screen.instance_variable_set(:@bootstrap_queue, queue)
      allow(screen).to receive(:typed_output)
      screen.send(:collect_bootstrap_result)
      expect(screen.instance_variable_get(:@bootstrap_data)).to eq({ files: ['crypt.json'], sections: ['crypt'] })
    end

    it 'leaves bootstrap_data nil when queue has nil data' do
      queue = Queue.new
      queue.push({ type: :bootstrap_complete, data: nil })
      screen.instance_variable_set(:@bootstrap_queue, queue)
      screen.send(:collect_bootstrap_result)
      expect(screen.instance_variable_get(:@bootstrap_data)).to be_nil
    end

    it 'shows configuration loaded message when data is present' do
      queue = Queue.new
      queue.push({ type: :bootstrap_complete, data: { files: ['crypt.json'], sections: ['crypt'] } })
      screen.instance_variable_set(:@bootstrap_queue, queue)
      expect(screen).to receive(:typed_output).with('Configuration loaded.')
      screen.send(:collect_bootstrap_result)
    end
  end

  describe '#run_extension_detection' do
    before do
      allow(screen).to receive(:typed_output)
      allow(screen).to receive(:sleep)
    end

    it 'skips when lex-detect gem is not available' do
      allow(screen).to receive(:detect_gem_available?).and_return(false)
      expect(screen).not_to receive(:typed_output)
      screen.send(:run_extension_detection)
    end

    it 'skips when detect queue returns no results' do
      allow(screen).to receive(:detect_gem_available?).and_return(true)
      queue = Queue.new
      queue.push({ type: :detect_complete, data: [] })
      screen.instance_variable_set(:@detect_queue, queue)
      expect(screen).not_to receive(:typed_output)
      screen.send(:run_extension_detection)
    end

    it 'displays hooking into lines for each detection' do
      allow(screen).to receive(:detect_gem_available?).and_return(true)
      queue = Queue.new
      queue.push({
                   type: :detect_complete,
                   data: [
                     { name: 'Claude', extensions: ['lex-claude'], installed: { 'lex-claude' => true } },
                     { name: 'Slack', extensions: ['lex-slack'], installed: { 'lex-slack' => true } }
                   ]
                 })
      screen.instance_variable_set(:@detect_queue, queue)
      expect(screen).to receive(:typed_output).with('  hooking into Claude...')
      expect(screen).to receive(:typed_output).with('  hooking into Slack...')
      expect(screen).to receive(:typed_output).with('All connections established.')
      screen.send(:run_extension_detection)
    end

    it 'offers to install missing extensions' do
      detect_mod = Module.new do
        def self.install_missing!
          { installed: ['lex-slack'], failed: [] }
        end
      end
      stub_const('Legion::Extensions::Detect', detect_mod)

      allow(screen).to receive(:detect_gem_available?).and_return(true)
      queue = Queue.new
      queue.push({
                   type: :detect_complete,
                   data: [
                     { name: 'Slack', extensions: ['lex-slack'], installed: { 'lex-slack' => false } }
                   ]
                 })
      screen.instance_variable_set(:@detect_queue, queue)
      allow(mock_wizard).to receive(:confirm).with('Install them now?').and_return(true)
      expect(screen).to receive(:typed_output).with('Extensions installed. Neural pathways expanded.')
      screen.send(:run_extension_detection)
    end

    it 'shows count of new connections when some are missing' do
      allow(screen).to receive(:detect_gem_available?).and_return(true)
      queue = Queue.new
      queue.push({
                   type: :detect_complete,
                   data: [
                     { name: 'Slack', extensions: ['lex-slack'], installed: { 'lex-slack' => false } },
                     { name: 'Todoist', extensions: ['lex-todoist'], installed: { 'lex-todoist' => false } }
                   ]
                 })
      screen.instance_variable_set(:@detect_queue, queue)
      allow(mock_wizard).to receive(:confirm).with('Install them now?').and_return(false)
      expect(screen).to receive(:typed_output).with('2 new connections available.')
      screen.send(:run_extension_detection)
    end
  end

  describe '#detect_gem_available?' do
    it 'returns false when lex-detect is not installed' do
      allow(screen).to receive(:require).with('legion/extensions/detect').and_raise(LoadError)
      expect(screen.send(:detect_gem_available?)).to be(false)
    end

    it 'returns true when lex-detect is installed' do
      allow(screen).to receive(:require).with('legion/extensions/detect').and_return(true)
      expect(screen.send(:detect_gem_available?)).to be(true)
    end
  end
end
