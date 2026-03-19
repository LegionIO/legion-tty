# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'legion/tty/session_store'

RSpec.describe Legion::TTY::SessionStore do
  let(:tmpdir) { Dir.mktmpdir }
  subject(:store) { described_class.new(dir: tmpdir) }

  after { FileUtils.remove_entry(tmpdir) }

  describe '#initialize' do
    it 'creates the session directory' do
      nested = File.join(tmpdir, 'deep', 'sessions')
      described_class.new(dir: nested)
      expect(Dir.exist?(nested)).to be true
    end
  end

  describe '#save' do
    let(:messages) do
      [
        { role: :user, content: 'Hello', tool_panels: [] },
        { role: :assistant, content: 'Hi there', tool_panels: [] }
      ]
    end

    it 'creates a JSON file' do
      store.save('test-session', messages: messages)
      expect(File.exist?(File.join(tmpdir, 'test-session.json'))).to be true
    end

    it 'stores messages in the file' do
      store.save('test-session', messages: messages)
      data = JSON.parse(File.read(File.join(tmpdir, 'test-session.json')))
      expect(data['messages'].size).to eq(2)
    end

    it 'includes metadata' do
      store.save('test-session', messages: messages, metadata: { model: 'claude' })
      data = JSON.parse(File.read(File.join(tmpdir, 'test-session.json')))
      expect(data['metadata']['model']).to eq('claude')
    end

    it 'sanitizes unsafe characters in name' do
      store.save('test/../../evil', messages: [])
      # The regex replaces non-alphanumeric/non-dash/non-underscore chars
      files = Dir.glob(File.join(tmpdir, '*.json'))
      expect(files.size).to eq(1)
      expect(File.basename(files.first)).not_to include('/')
    end
  end

  describe '#load' do
    it 'returns nil when session does not exist' do
      expect(store.load('nonexistent')).to be_nil
    end

    it 'returns session data with symbolized keys' do
      store.save('test', messages: [{ role: :user, content: 'hi', tool_panels: [] }])
      data = store.load('test')
      expect(data[:name]).to eq('test')
      expect(data[:messages]).to be_an(Array)
    end

    it 'deserializes message roles as symbols' do
      store.save('test', messages: [{ role: :user, content: 'hello', tool_panels: [] }])
      data = store.load('test')
      expect(data[:messages].first[:role]).to eq(:user)
    end

    it 'returns nil for corrupted JSON' do
      File.write(File.join(tmpdir, 'bad.json'), 'not json at all')
      expect(store.load('bad')).to be_nil
    end
  end

  describe '#list' do
    it 'returns empty array when no sessions' do
      expect(store.list).to eq([])
    end

    it 'returns session metadata' do
      store.save('session-a', messages: [{ role: :user, content: 'a', tool_panels: [] }])
      store.save('session-b', messages: [
                   { role: :user, content: 'b', tool_panels: [] },
                   { role: :assistant, content: 'c', tool_panels: [] }
                 ])
      list = store.list
      expect(list.size).to eq(2)
      names = list.map { |s| s[:name] }
      expect(names).to include('session-a', 'session-b')
    end

    it 'includes message count' do
      store.save('counted', messages: [
                   { role: :user, content: 'a', tool_panels: [] },
                   { role: :assistant, content: 'b', tool_panels: [] },
                   { role: :user, content: 'c', tool_panels: [] }
                 ])
      entry = store.list.find { |s| s[:name] == 'counted' }
      expect(entry[:message_count]).to eq(3)
    end

    it 'sorts by saved_at descending (most recent first)' do
      store.save('old', messages: [])
      # Backdate the 'old' session file instead of sleeping
      old_path = File.join(tmpdir, 'old.json')
      data = JSON.parse(File.read(old_path))
      data['saved_at'] = (Time.now - 60).iso8601
      File.write(old_path, JSON.generate(data))
      store.save('new', messages: [])
      list = store.list
      expect(list.first[:name]).to eq('new')
    end
  end

  describe '#delete' do
    it 'removes the session file' do
      store.save('doomed', messages: [])
      store.delete('doomed')
      expect(store.load('doomed')).to be_nil
    end

    it 'does not raise when session does not exist' do
      expect { store.delete('ghost') }.not_to raise_error
    end
  end

  describe '#auto_session_name' do
    it 'returns a string starting with session- when no messages given' do
      expect(store.auto_session_name).to start_with('session-')
    end

    it 'includes a 6-digit timestamp when no messages given' do
      name = store.auto_session_name
      expect(name).to match(/session-\d{6}/)
    end
  end
end
