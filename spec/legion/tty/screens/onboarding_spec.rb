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
                    confirm: true)
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
end
