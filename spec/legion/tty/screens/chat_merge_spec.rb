# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/merge command' do
  let(:output) { StringIO.new }
  let(:reader) { double('reader', read_line: nil) }
  let(:input_bar) { Legion::TTY::Components::InputBar.new(name: 'Test', reader: reader) }
  let(:app) do
    instance_double('Legion::TTY::App',
                    config: { provider: 'claude' },
                    llm_chat: nil,
                    screen_manager: double('sm', overlay: nil, push: nil, pop: nil,
                                                 dismiss_overlay: nil, show_overlay: nil),
                    hotkeys: double('hk', list: []),
                    respond_to?: true)
  end

  before do
    allow(reader).to receive(:on)
    allow(app).to receive(:respond_to?).with(:config).and_return(true)
    allow(app).to receive(:respond_to?).with(:llm_chat).and_return(true)
    allow(app).to receive(:respond_to?).with(:screen_manager).and_return(true)
    allow(app).to receive(:respond_to?).with(:hotkeys).and_return(true)
    allow(app).to receive(:respond_to?).with(:toggle_dashboard).and_return(false)
  end

  subject(:chat) { described_class.new(app, output: output, input_bar: input_bar) }

  describe 'SLASH_COMMANDS' do
    it 'includes /merge' do
      expect(described_class::SLASH_COMMANDS).to include('/merge')
    end
  end

  describe '/merge without session name' do
    it 'returns :handled' do
      result = chat.handle_slash_command('/merge')
      expect(result).to eq(:handled)
    end

    it 'shows usage message' do
      chat.handle_slash_command('/merge')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Usage:')
      expect(msgs.last[:content]).to include('/merge')
    end
  end

  describe '/merge with non-existent session' do
    it 'returns :handled' do
      session_store = instance_double(Legion::TTY::SessionStore, load: nil)
      chat.instance_variable_set(:@session_store, session_store)
      result = chat.handle_slash_command('/merge ghost-session')
      expect(result).to eq(:handled)
    end

    it 'shows "Session not found." message' do
      session_store = instance_double(Legion::TTY::SessionStore, load: nil)
      chat.instance_variable_set(:@session_store, session_store)
      chat.handle_slash_command('/merge ghost-session')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to eq('Session not found.')
    end
  end

  describe '/merge with existing session' do
    let(:merged_messages) do
      [
        { role: :user, content: 'imported question' },
        { role: :assistant, content: 'imported answer' }
      ]
    end

    before do
      session_store = instance_double(Legion::TTY::SessionStore,
                                      load: { messages: merged_messages, name: 'other' })
      chat.instance_variable_set(:@session_store, session_store)
    end

    it 'returns :handled' do
      result = chat.handle_slash_command('/merge other')
      expect(result).to eq(:handled)
    end

    it 'appends the imported messages to the current stream' do
      chat.message_stream.add_message(role: :user, content: 'existing message')
      chat.handle_slash_command('/merge other')
      contents = chat.message_stream.messages.map { |m| m[:content] }
      expect(contents).to include('existing message')
      expect(contents).to include('imported question')
      expect(contents).to include('imported answer')
    end

    it 'shows count of merged messages' do
      chat.handle_slash_command('/merge other')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('2')
    end

    it 'includes session name in confirmation' do
      chat.handle_slash_command('/merge other')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('other')
    end

    it 'does not replace existing messages, only appends' do
      chat.message_stream.add_message(role: :user, content: 'original')
      original_count = chat.message_stream.messages.size
      chat.handle_slash_command('/merge other')
      # merged 2 + 1 system confirmation appended after
      expect(chat.message_stream.messages.size).to be > original_count + 1
    end

    it 'updates message_count in status bar' do
      expect(chat.status_bar).to receive(:update).with(hash_including(message_count: anything))
      chat.handle_slash_command('/merge other')
    end
  end
end
