# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/grep and /time commands' do
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
    allow(app).to receive(:respond_to?).with(:hotkeys).and_return(false)
    allow(app).to receive(:respond_to?).with(:toggle_dashboard).and_return(false)
  end

  subject(:chat) { described_class.new(app, output: output, input_bar: input_bar) }

  # ---------------------------------------------------------------------------
  # /grep
  # ---------------------------------------------------------------------------
  describe '/grep' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/grep')
    end

    it 'returns :handled' do
      result = chat.handle_slash_command('/grep hello')
      expect(result).to eq(:handled)
    end

    it 'requires a pattern argument' do
      result = chat.handle_slash_command('/grep')
      expect(result).to eq(:handled)
      expect(chat.message_stream.messages.last[:content]).to include('Usage:')
    end

    it 'finds messages matching a literal pattern' do
      chat.message_stream.add_message(role: :user, content: 'hello world')
      chat.message_stream.add_message(role: :assistant, content: 'goodbye world')
      result = chat.handle_slash_command('/grep hello')
      expect(result).to eq(:handled)
      expect(chat.message_stream.messages.last[:content]).to include('1 message(s)')
    end

    it 'finds messages matching a regex pattern' do
      chat.message_stream.add_message(role: :user, content: 'foo123')
      chat.message_stream.add_message(role: :assistant, content: 'bar456')
      result = chat.handle_slash_command('/grep foo\\d+')
      expect(result).to eq(:handled)
      expect(chat.message_stream.messages.last[:content]).to include('1 message(s)')
    end

    it 'matches case-insensitively' do
      chat.message_stream.add_message(role: :user, content: 'Hello World')
      result = chat.handle_slash_command('/grep hello')
      expect(result).to eq(:handled)
      expect(chat.message_stream.messages.last[:content]).to include('1 message(s)')
    end

    it 'reports no results when pattern does not match' do
      chat.message_stream.add_message(role: :user, content: 'hello')
      result = chat.handle_slash_command('/grep zzz')
      expect(result).to eq(:handled)
      expect(chat.message_stream.messages.last[:content]).to include('No messages matching')
    end

    it 'handles invalid regex gracefully' do
      result = chat.handle_slash_command('/grep [invalid')
      expect(result).to eq(:handled)
      expect(chat.message_stream.messages.last[:content]).to include('Invalid regex')
    end

    it 'matches multiple messages' do
      chat.message_stream.add_message(role: :user, content: 'apple pie')
      chat.message_stream.add_message(role: :assistant, content: 'apple cider')
      chat.message_stream.add_message(role: :user, content: 'orange juice')
      result = chat.handle_slash_command('/grep apple')
      expect(result).to eq(:handled)
      expect(chat.message_stream.messages.last[:content]).to include('2 message(s)')
    end

    it 'is mentioned in /help text' do
      chat.handle_slash_command('/help')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('/grep')
    end
  end

  # ---------------------------------------------------------------------------
  # /time
  # ---------------------------------------------------------------------------
  describe '/time' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/time')
    end

    it 'returns :handled' do
      result = chat.handle_slash_command('/time')
      expect(result).to eq(:handled)
    end

    it 'shows the current date in YYYY-MM-DD format' do
      chat.handle_slash_command('/time')
      content = chat.message_stream.messages.last[:content]
      expect(content).to match(/\d{4}-\d{2}-\d{2}/)
    end

    it 'shows the current time in HH:MM:SS format' do
      chat.handle_slash_command('/time')
      content = chat.message_stream.messages.last[:content]
      expect(content).to match(/\d{2}:\d{2}:\d{2}/)
    end

    it 'includes the timezone' do
      chat.handle_slash_command('/time')
      content = chat.message_stream.messages.last[:content]
      # Time.now.zone returns the timezone abbreviation (e.g. CST, UTC, EDT)
      expect(content).to match(/[A-Z]{2,5}/)
    end

    it 'includes "Current time:" label' do
      chat.handle_slash_command('/time')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Current time:')
    end

    it 'is mentioned in /help text' do
      chat.handle_slash_command('/help')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('/time')
    end
  end
end
