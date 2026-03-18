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
    it 'returns a config hash with name and provider' do
      allow(screen).to receive(:run_rain)
      allow(screen).to receive(:run_intro)
      allow(screen).to receive(:start_background_threads)
      allow(screen).to receive(:collect_background_results).and_return([nil, nil])
      allow(screen).to receive(:run_reveal).and_return(true)
      result = screen.activate
      expect(result).to include(:name, :provider)
    end

    it 'skips rain when skip_rain is true' do
      allow(screen).to receive(:run_intro)
      allow(screen).to receive(:start_background_threads)
      allow(screen).to receive(:collect_background_results).and_return([nil, nil])
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
    it 'returns the kerberos samaccountname when available' do
      screen.instance_variable_set(:@kerberos_identity, { samaccountname: 'jdoe', first_name: 'Jane' })
      expect(screen.send(:default_vault_username)).to eq('jdoe')
    end

    it 'falls back to ENV USER when no kerberos identity' do
      screen.instance_variable_set(:@kerberos_identity, nil)
      allow(ENV).to receive(:fetch).with('USER', 'unknown').and_return('testuser')
      expect(screen.send(:default_vault_username)).to eq('testuser')
    end

    it 'falls back to ENV USER when kerberos identity has no samaccountname' do
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
end
