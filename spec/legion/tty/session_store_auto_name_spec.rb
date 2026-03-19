# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'legion/tty/session_store'

RSpec.describe Legion::TTY::SessionStore, 'auto naming' do
  let(:store) { described_class.new(dir: Dir.mktmpdir) }

  describe '#auto_session_name' do
    it 'generates name from first user message' do
      msgs = [{ role: :user, content: 'How do I configure Vault?' }]
      name = store.auto_session_name(messages: msgs)
      expect(name).to eq('how-do-i-configure')
    end

    it 'returns timestamp-based name for empty messages' do
      name = store.auto_session_name(messages: [])
      expect(name).to match(/^session-\d{6}$/)
    end

    it 'strips special characters' do
      msgs = [{ role: :user, content: 'Fix the @#$ bug!' }]
      name = store.auto_session_name(messages: msgs)
      expect(name).to eq('fix-the-bug')
    end

    it 'limits to 4 words' do
      msgs = [{ role: :user, content: 'one two three four five six' }]
      name = store.auto_session_name(messages: msgs)
      expect(name).to eq('one-two-three-four')
    end

    it 'skips system messages' do
      msgs = [{ role: :system, content: 'Welcome' }, { role: :user, content: 'hello' }]
      name = store.auto_session_name(messages: msgs)
      expect(name).to eq('hello')
    end
  end
end
