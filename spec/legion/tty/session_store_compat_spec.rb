# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'legion/tty/session_store'

RSpec.describe Legion::TTY::SessionStore, 'session format compatibility' do
  let(:tmpdir) { Dir.mktmpdir }
  subject(:store) { described_class.new(dir: tmpdir) }

  after { FileUtils.remove_entry(tmpdir) }

  describe 'SESSION_DIR constant' do
    it 'points to ~/.legionio/sessions' do
      expect(Legion::TTY::SessionStore::SESSION_DIR).to eq(File.expand_path('~/.legionio/sessions'))
    end

    it 'does not reference the legacy ~/.legion path' do
      expect(Legion::TTY::SessionStore::SESSION_DIR).not_to include('/.legion/')
      expect(Legion::TTY::SessionStore::SESSION_DIR).not_to eq(File.expand_path('~/.legion/sessions'))
    end
  end

  describe '#load with TTY v1 format' do
    it 'loads a session with version: 1 and symbol roles' do
      store.save('tty-session', messages: [{ role: :user, content: 'hello', tool_panels: [] }])
      data = store.load('tty-session')
      expect(data[:version]).to eq(1)
      expect(data[:messages].first[:role]).to eq(:user)
    end

    it 'preserves metadata from TTY format' do
      store.save('tty-meta', messages: [], metadata: { model: 'claude', tokens: 42 })
      data = store.load('tty-meta')
      expect(data[:metadata][:model]).to eq('claude')
    end
  end

  describe '#load with CLI (legacy) format' do
    let(:cli_session) do
      {
        messages: [
          { role: 'user', content: 'What is Vault?', model: 'claude-3-5-sonnet',
            stats: { tokens: 100 }, summary: nil },
          { role: 'assistant', content: 'Vault is a secrets manager.', model: 'claude-3-5-sonnet',
            stats: { tokens: 200 }, summary: 'vault summary' }
        ],
        saved_at: '2025-01-01T00:00:00Z'
      }
    end

    before do
      File.write(File.join(tmpdir, 'cli-session.json'), JSON.generate(cli_session))
    end

    it 'loads CLI format without raising' do
      expect { store.load('cli-session') }.not_to raise_error
    end

    it 'normalizes role strings to symbols' do
      data = store.load('cli-session')
      roles = data[:messages].map { |m| m[:role] }
      expect(roles).to all(be_a(Symbol))
      expect(roles).to eq(%i[user assistant])
    end

    it 'preserves content from CLI messages' do
      data = store.load('cli-session')
      expect(data[:messages].first[:content]).to eq('What is Vault?')
      expect(data[:messages].last[:content]).to eq('Vault is a secrets manager.')
    end

    it 'sets default version to 1 when missing' do
      data = store.load('cli-session')
      expect(data[:version]).to eq(1)
    end

    it 'sets default metadata to empty hash when missing' do
      data = store.load('cli-session')
      expect(data[:metadata]).to eq({})
    end

    it 'sets a default name when missing' do
      data = store.load('cli-session')
      expect(data[:name]).to eq('imported')
    end

    it 'adds tool_panels to each normalized message' do
      data = store.load('cli-session')
      expect(data[:messages]).to all(include(tool_panels: []))
    end
  end

  describe '#load with missing optional fields' do
    it 'fills in defaults for a minimal session' do
      File.write(File.join(tmpdir, 'minimal.json'), JSON.generate({ messages: [] }))
      data = store.load('minimal')
      expect(data[:version]).to eq(1)
      expect(data[:metadata]).to eq({})
      expect(data[:name]).to eq('imported')
      expect(data[:saved_at]).not_to be_nil
    end
  end
end
