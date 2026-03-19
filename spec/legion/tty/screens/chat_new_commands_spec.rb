# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, 'new commands' do
  let(:output) { StringIO.new }
  let(:reader) { double('reader', read_line: nil) }
  let(:input_bar) { Legion::TTY::Components::InputBar.new(name: 'Test', reader: reader) }
  let(:app) do
    instance_double('Legion::TTY::App',
                    config: { provider: 'claude' },
                    llm_chat: nil,
                    screen_manager: double('sm', overlay: nil, push: nil, pop: nil, dismiss_overlay: nil),
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

  # -----------------------------------------------------------------------
  # Feature 1: StatusBar notifications wired from chat commands
  # -----------------------------------------------------------------------
  describe 'notification wiring' do
    it '/save calls status_bar.notify with :success level' do
      expect(chat.status_bar).to receive(:notify).with(hash_including(level: :success))
      chat.handle_slash_command('/save test-notify')
    end

    it '/load calls status_bar.notify with :info level when session exists' do
      session_store = instance_double(Legion::TTY::SessionStore,
                                      load: { messages: [], name: 'test-notify' })
      chat.instance_variable_set(:@session_store, session_store)
      expect(chat.status_bar).to receive(:notify).with(hash_including(level: :info))
      chat.handle_slash_command('/load test-notify')
    end

    it '/load does not notify when session not found' do
      session_store = instance_double(Legion::TTY::SessionStore, load: nil)
      chat.instance_variable_set(:@session_store, session_store)
      expect(chat.status_bar).not_to receive(:notify)
      chat.handle_slash_command('/load missing')
    end

    it '/export calls status_bar.notify with :success level' do
      expect(chat.status_bar).to receive(:notify).with(hash_including(level: :success))
      chat.handle_slash_command('/export')
    end

    it '/theme calls status_bar.notify with :info level on valid theme' do
      allow(Legion::TTY::Theme).to receive(:switch).and_return(true)
      expect(chat.status_bar).to receive(:notify).with(hash_including(level: :info, ttl: 2))
      chat.handle_slash_command('/theme purple')
    end

    it '/theme does not notify on unknown theme' do
      allow(Legion::TTY::Theme).to receive(:switch).and_return(false)
      allow(Legion::TTY::Theme).to receive(:available_themes).and_return(%w[purple green])
      expect(chat.status_bar).not_to receive(:notify)
      chat.handle_slash_command('/theme unknown')
    end
  end

  # -----------------------------------------------------------------------
  # Feature 2: /undo
  # -----------------------------------------------------------------------
  describe '/undo' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/undo')
    end

    it 'returns :handled' do
      result = chat.handle_slash_command('/undo')
      expect(result).to eq(:handled)
    end

    it 'shows "Nothing to undo" when no user messages exist' do
      result = chat.handle_slash_command('/undo')
      expect(result).to eq(:handled)
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to eq('Nothing to undo.')
    end

    it 'removes the last user message and everything after it' do
      chat.message_stream.add_message(role: :user, content: 'first')
      chat.message_stream.add_message(role: :assistant, content: 'response one')
      chat.message_stream.add_message(role: :user, content: 'second')
      chat.message_stream.add_message(role: :assistant, content: 'response two')
      chat.handle_slash_command('/undo')
      contents = chat.message_stream.messages.map { |m| m[:content] }
      expect(contents).to include('first', 'response one')
      expect(contents).not_to include('second', 'response two')
    end

    it 'removes only the last user message pair, preserving earlier messages' do
      chat.message_stream.add_message(role: :user, content: 'keep me')
      chat.message_stream.add_message(role: :assistant, content: 'keep response')
      chat.message_stream.add_message(role: :user, content: 'remove me')
      chat.message_stream.add_message(role: :assistant, content: 'remove response')
      chat.handle_slash_command('/undo')
      expect(chat.message_stream.messages.size).to eq(2)
    end

    it 'can undo when only a user message exists with no assistant reply' do
      chat.message_stream.add_message(role: :user, content: 'lone user msg')
      chat.handle_slash_command('/undo')
      user_msgs = chat.message_stream.messages.select { |m| m[:role] == :user }
      expect(user_msgs).to be_empty
    end
  end

  # -----------------------------------------------------------------------
  # Feature 3: /history
  # -----------------------------------------------------------------------
  describe '/history' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/history')
    end

    it 'returns :handled' do
      result = chat.handle_slash_command('/history')
      expect(result).to eq(:handled)
    end

    it 'shows "No input history" when history is empty' do
      allow(input_bar).to receive(:history).and_return([])
      result = chat.handle_slash_command('/history')
      expect(result).to eq(:handled)
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to eq('No input history.')
    end

    it 'shows numbered history entries' do
      allow(input_bar).to receive(:history).and_return(['hello', '/help', '/clear'])
      chat.handle_slash_command('/history')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      content = msgs.last[:content]
      expect(content).to include('hello')
      expect(content).to include('/help')
      expect(content).to include('/clear')
      expect(content).to include('1.')
    end

    it 'shows at most 20 entries' do
      entries = (1..30).map { |i| "entry #{i}" }
      allow(input_bar).to receive(:history).and_return(entries)
      chat.handle_slash_command('/history')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      content = msgs.last[:content]
      expect(content).to include('20')
      expect(content).not_to include('entry 1 ')
      expect(content).to include('entry 30')
    end
  end

  # -----------------------------------------------------------------------
  # Feature 4: /pin and /pins
  # -----------------------------------------------------------------------
  describe '/pin' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/pin')
    end

    it 'returns :handled' do
      result = chat.handle_slash_command('/pin')
      expect(result).to eq(:handled)
    end

    it 'reports "No message to pin" when no assistant message exists' do
      result = chat.handle_slash_command('/pin')
      expect(result).to eq(:handled)
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to eq('No message to pin.')
    end

    it 'pins the last assistant message when no index given' do
      chat.message_stream.add_message(role: :assistant, content: 'pin me')
      chat.handle_slash_command('/pin')
      pinned = chat.instance_variable_get(:@pinned_messages)
      expect(pinned.size).to eq(1)
      expect(pinned.first[:content]).to eq('pin me')
    end

    it 'shows a preview of the pinned message' do
      chat.message_stream.add_message(role: :assistant, content: 'the answer')
      chat.handle_slash_command('/pin')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('the answer')
    end

    it 'pins a message at a specific index' do
      chat.message_stream.add_message(role: :user, content: 'user msg')
      chat.message_stream.add_message(role: :assistant, content: 'assistant msg')
      chat.handle_slash_command('/pin 0')
      pinned = chat.instance_variable_get(:@pinned_messages)
      expect(pinned.first[:content]).to eq('user msg')
    end

    it 'reports "No message to pin" for an out-of-range index' do
      chat.handle_slash_command('/pin 99')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to eq('No message to pin.')
    end
  end

  describe '/pins' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/pins')
    end

    it 'returns :handled' do
      result = chat.handle_slash_command('/pins')
      expect(result).to eq(:handled)
    end

    it 'reports "No pinned messages" when none exist' do
      result = chat.handle_slash_command('/pins')
      expect(result).to eq(:handled)
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to eq('No pinned messages.')
    end

    it 'lists all pinned messages with index and preview' do
      chat.instance_variable_set(:@pinned_messages, [
                                   { role: :assistant, content: 'first pinned' },
                                   { role: :assistant, content: 'second pinned' }
                                 ])
      chat.handle_slash_command('/pins')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      content = msgs.last[:content]
      expect(content).to include('first pinned')
      expect(content).to include('second pinned')
      expect(content).to include('1.')
      expect(content).to include('2.')
    end
  end

  # -----------------------------------------------------------------------
  # Feature 5: /rename
  # -----------------------------------------------------------------------
  describe '/rename' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/rename')
    end

    it 'returns :handled' do
      result = chat.handle_slash_command('/rename new-name')
      expect(result).to eq(:handled)
    end

    it 'shows usage when no name given' do
      result = chat.handle_slash_command('/rename')
      expect(result).to eq(:handled)
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to eq('Usage: /rename <new-name>')
    end

    it 'updates @session_name to the new name' do
      chat.handle_slash_command('/rename my-new-session')
      expect(chat.instance_variable_get(:@session_name)).to eq('my-new-session')
    end

    it 'updates the status bar session' do
      expect(chat.status_bar).to receive(:update).with(hash_including(session: 'renamed'))
      chat.handle_slash_command('/rename renamed')
    end

    it 'shows confirmation message with new name' do
      chat.handle_slash_command('/rename cool-session')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('cool-session')
    end

    it 'deletes the old session file when not default' do
      session_store = instance_double(Legion::TTY::SessionStore, save: nil, delete: nil)
      chat.instance_variable_set(:@session_store, session_store)
      chat.instance_variable_set(:@session_name, 'old-name')
      chat.handle_slash_command('/rename new-name')
      expect(session_store).to have_received(:delete).with('old-name')
      expect(session_store).to have_received(:save).with('new-name', messages: anything)
    end

    it 'does not delete the session file when current name is default' do
      session_store = instance_double(Legion::TTY::SessionStore, save: nil)
      chat.instance_variable_set(:@session_store, session_store)
      chat.instance_variable_set(:@session_name, 'default')
      expect(session_store).not_to receive(:delete)
      chat.handle_slash_command('/rename new-name')
    end
  end

  # -----------------------------------------------------------------------
  # Help text
  # -----------------------------------------------------------------------
  describe '/help includes new commands' do
    it 'mentions /undo in help text' do
      chat.handle_slash_command('/help')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('/undo')
    end

    it 'mentions /history in help text' do
      chat.handle_slash_command('/help')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('/history')
    end

    it 'mentions /pin in help text' do
      chat.handle_slash_command('/help')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('/pin')
    end

    it 'mentions /pins in help text' do
      chat.handle_slash_command('/help')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('/pins')
    end

    it 'mentions /rename in help text' do
      chat.handle_slash_command('/help')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('/rename')
    end
  end
end
