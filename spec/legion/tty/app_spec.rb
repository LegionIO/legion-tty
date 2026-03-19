# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'legion/tty/app'

RSpec.describe Legion::TTY::App do
  describe '.first_run?' do
    it 'returns true when identity.json does not exist' do
      Dir.mktmpdir do |dir|
        expect(described_class.first_run?(config_dir: dir)).to be true
      end
    end

    it 'returns false when identity.json exists' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'identity.json'), '{}')
        expect(described_class.first_run?(config_dir: dir)).to be false
      end
    end
  end

  describe '#initialize' do
    it 'loads config from identity.json when present' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'identity.json'), '{"name":"Matt","provider":"claude"}')
        app = described_class.new(config_dir: dir)
        expect(app.config[:name]).to eq('Matt')
      end
    end

    it 'returns empty hash config when identity.json missing' do
      Dir.mktmpdir do |dir|
        app = described_class.new(config_dir: dir)
        expect(app.config).to eq({})
      end
    end
  end

  describe '#config' do
    it 'returns a hash' do
      Dir.mktmpdir do |dir|
        app = described_class.new(config_dir: dir)
        expect(app.config).to be_a(Hash)
      end
    end
  end

  describe '#screen_manager' do
    it 'returns a ScreenManager' do
      Dir.mktmpdir do |dir|
        app = described_class.new(config_dir: dir)
        expect(app.screen_manager).to be_a(Legion::TTY::ScreenManager)
      end
    end

    it 'returns the same instance on repeated calls' do
      Dir.mktmpdir do |dir|
        app = described_class.new(config_dir: dir)
        expect(app.screen_manager).to equal(app.screen_manager)
      end
    end
  end

  describe '#hotkeys' do
    it 'returns a Hotkeys instance' do
      Dir.mktmpdir do |dir|
        app = described_class.new(config_dir: dir)
        expect(app.hotkeys).to be_a(Legion::TTY::Hotkeys)
      end
    end
  end

  describe '#save_config' do
    it 'writes identity.json' do
      Dir.mktmpdir do |dir|
        app = described_class.new(config_dir: dir)
        app.save_config({ name: 'Matt', provider: 'claude', api_key: 'sk-test' })
        expect(File.exist?(File.join(dir, 'identity.json'))).to be true
      end
    end

    it 'writes credentials.json' do
      Dir.mktmpdir do |dir|
        app = described_class.new(config_dir: dir)
        app.save_config({ name: 'Matt', provider: 'claude', api_key: 'sk-test' })
        expect(File.exist?(File.join(dir, 'credentials.json'))).to be true
      end
    end

    it 'does not write api_key to identity.json' do
      Dir.mktmpdir do |dir|
        app = described_class.new(config_dir: dir)
        app.save_config({ name: 'Matt', provider: 'claude', api_key: 'sk-test' })
        identity = JSON.parse(File.read(File.join(dir, 'identity.json')))
        expect(identity).not_to have_key('api_key')
      end
    end

    it 'writes api_key to credentials.json' do
      Dir.mktmpdir do |dir|
        app = described_class.new(config_dir: dir)
        app.save_config({ name: 'Matt', provider: 'claude', api_key: 'sk-test' })
        creds = JSON.parse(File.read(File.join(dir, 'credentials.json')))
        expect(creds['api_key']).to eq('sk-test')
      end
    end
  end

  describe '#shutdown' do
    it 'calls teardown_all on screen_manager' do
      Dir.mktmpdir do |dir|
        app = described_class.new(config_dir: dir)
        expect(app.screen_manager).to receive(:teardown_all)
        app.shutdown
      end
    end
  end

  describe '#setup_llm' do
    it 'sets llm_chat to nil when Legion::LLM is not available' do
      Dir.mktmpdir do |dir|
        app = described_class.new(config_dir: dir)
        allow(app).to receive(:boot_legion_subsystems)
        allow(app).to receive(:try_settings_llm).and_return(nil)
        app.send(:setup_llm)
        expect(app.llm_chat).to be_nil
      end
    end
  end

  describe '#setup_hotkeys' do
    it 'registers Ctrl+D for toggle dashboard' do
      Dir.mktmpdir do |dir|
        app = described_class.new(config_dir: dir)
        app.setup_hotkeys
        keys = app.hotkeys.list.map { |b| b[:key] }
        expect(keys).to include("\x04")
      end
    end

    it 'registers Ctrl+L for refresh' do
      Dir.mktmpdir do |dir|
        app = described_class.new(config_dir: dir)
        app.setup_hotkeys
        keys = app.hotkeys.list.map { |b| b[:key] }
        expect(keys).to include("\x0C")
      end
    end

    it 'registers Ctrl+K for command palette' do
      Dir.mktmpdir do |dir|
        app = described_class.new(config_dir: dir)
        app.setup_hotkeys
        keys = app.hotkeys.list.map { |b| b[:key] }
        expect(keys).to include("\x0B")
      end
    end

    it 'registers Ctrl+S for session picker' do
      Dir.mktmpdir do |dir|
        app = described_class.new(config_dir: dir)
        app.setup_hotkeys
        keys = app.hotkeys.list.map { |b| b[:key] }
        expect(keys).to include("\x13")
      end
    end

    it 'registers Escape for go back' do
      Dir.mktmpdir do |dir|
        app = described_class.new(config_dir: dir)
        app.setup_hotkeys
        keys = app.hotkeys.list.map { |b| b[:key] }
        expect(keys).to include("\e")
      end
    end

    it 'does NOT register ? as a hotkey' do
      Dir.mktmpdir do |dir|
        app = described_class.new(config_dir: dir)
        app.setup_hotkeys
        keys = app.hotkeys.list.map { |b| b[:key] }
        expect(keys).not_to include('?')
      end
    end
  end
end
