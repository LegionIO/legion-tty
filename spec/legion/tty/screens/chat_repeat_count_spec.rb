# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/repeat and /count' do
  let(:output) { StringIO.new }
  let(:reader) { double('reader', read_line: nil) }
  let(:input_bar) { Legion::TTY::Components::InputBar.new(name: 'Test', reader: reader) }
  let(:app) do
    instance_double('Legion::TTY::App',
                    config: { provider: 'claude' },
                    llm_chat: nil,
                    screen_manager: double('sm', overlay: nil, push: nil, pop: nil, dismiss_overlay: nil,
                                                 show_overlay: nil),
                    hotkeys: double('hk', list: []),
                    respond_to?: true)
  end

  before do
    allow(reader).to receive(:on)
    allow(app).to receive(:respond_to?).with(:config).and_return(true)
    allow(app).to receive(:respond_to?).with(:llm_chat).and_return(true)
    allow(app).to receive(:respond_to?).with(:screen_manager).and_return(true)
    allow(app).to receive(:respond_to?).with(:hotkeys).and_return(false)
    allow(app).to receive(:respond_to?).with(:toggle_dashboard).and_return(false)
  end

  subject(:chat) { described_class.new(app, output: output, input_bar: input_bar) }

  # -----------------------------------------------------------------------
  # /repeat
  # -----------------------------------------------------------------------
  describe '/repeat' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/repeat')
    end

    it 'returns :handled' do
      result = chat.handle_slash_command('/repeat')
      expect(result).to eq(:handled)
    end

    it 'shows "No previous command to repeat." when no prior command exists' do
      chat.handle_slash_command('/repeat')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to eq('No previous command to repeat.')
    end

    it 'stores the last command after any slash command' do
      chat.handle_slash_command('/clear')
      expect(chat.instance_variable_get(:@last_command)).to eq('/clear')
    end

    it 'stores the last command with its argument' do
      chat.handle_slash_command('/search hello')
      expect(chat.instance_variable_get(:@last_command)).to eq('/search hello')
    end

    it 'does not update @last_command when /repeat is called' do
      chat.handle_slash_command('/clear')
      expect(chat.instance_variable_get(:@last_command)).to eq('/clear')
      chat.handle_slash_command('/repeat')
      expect(chat.instance_variable_get(:@last_command)).to eq('/clear')
    end

    it 're-executes the last command' do
      chat.handle_slash_command('/wc')
      initial_count = chat.message_stream.messages.size
      chat.handle_slash_command('/repeat')
      # repeat re-runs /wc which adds another system message
      expect(chat.message_stream.messages.size).to be > initial_count
    end

    it 'repeats /search and re-runs the search' do
      chat.message_stream.add_message(role: :user, content: 'hello world')
      chat.handle_slash_command('/search hello')
      before_count = chat.message_stream.messages.size
      chat.handle_slash_command('/repeat')
      after_count = chat.message_stream.messages.size
      # /repeat re-runs /search, adding another result message
      expect(after_count).to be > before_count
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('hello')
    end

    it 'initializes @last_command to nil' do
      expect(chat.instance_variable_get(:@last_command)).to be_nil
    end
  end

  # -----------------------------------------------------------------------
  # /count
  # -----------------------------------------------------------------------
  describe '/count' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/count')
    end

    it 'returns :handled' do
      result = chat.handle_slash_command('/count hello')
      expect(result).to eq(:handled)
    end

    it 'shows usage when no pattern given' do
      chat.handle_slash_command('/count')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to eq('Usage: /count <pattern>')
    end

    it 'reports 0 when no messages match' do
      chat.handle_slash_command('/count zzznomatch')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include("0 messages matching 'zzznomatch'")
    end

    it 'counts matching messages' do
      chat.message_stream.add_message(role: :user, content: 'hello world')
      chat.message_stream.add_message(role: :assistant, content: 'hello there')
      chat.message_stream.add_message(role: :user, content: 'goodbye world')
      chat.handle_slash_command('/count hello')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('2 message(s)')
    end

    it 'includes role breakdown when matches exist' do
      chat.message_stream.add_message(role: :user, content: 'hello')
      chat.message_stream.add_message(role: :assistant, content: 'hello back')
      chat.handle_slash_command('/count hello')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      content = msgs.last[:content]
      expect(content).to include('user:')
      expect(content).to include('assistant:')
    end

    it 'is case-insensitive' do
      chat.message_stream.add_message(role: :user, content: 'Hello World')
      chat.handle_slash_command('/count hello')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('1 message(s)')
    end

    it 'counts only exact pattern matches (not partial role labels)' do
      chat.message_stream.add_message(role: :user, content: 'ruby is great')
      chat.message_stream.add_message(role: :user, content: 'python is also great')
      chat.handle_slash_command('/count ruby')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('1 message(s)')
    end

    it 'handles multi-word patterns' do
      chat.message_stream.add_message(role: :user, content: 'hello world today')
      chat.message_stream.add_message(role: :user, content: 'hello there')
      chat.handle_slash_command('/count hello world')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('1 message(s)')
    end
  end
end
