# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, 'scroll shortcut and peek commands' do
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
    allow(app).to receive(:respond_to?).with(:hotkeys).and_return(true)
    allow(app).to receive(:respond_to?).with(:toggle_dashboard).and_return(false)
  end

  subject(:chat) { described_class.new(app, output: output, input_bar: input_bar) }

  describe '/top' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/top')
    end

    it 'returns :handled' do
      expect(chat.handle_slash_command('/top')).to eq(:handled)
    end

    it 'increases scroll_offset (scrolls toward top)' do
      5.times { chat.message_stream.add_message(role: :user, content: 'msg') }
      chat.handle_slash_command('/top')
      expect(chat.message_stream.scroll_offset).to be > 0
    end

    it 'does not add a visible message to the stream' do
      initial_count = chat.message_stream.messages.size
      chat.handle_slash_command('/top')
      expect(chat.message_stream.messages.size).to eq(initial_count)
    end
  end

  describe '/bottom' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/bottom')
    end

    it 'returns :handled' do
      expect(chat.handle_slash_command('/bottom')).to eq(:handled)
    end

    it 'resets scroll_offset to 0' do
      chat.message_stream.scroll_up(10)
      chat.handle_slash_command('/bottom')
      expect(chat.message_stream.scroll_offset).to eq(0)
    end

    it 'does not add a visible message to the stream' do
      chat.message_stream.scroll_up(5)
      initial_count = chat.message_stream.messages.size
      chat.handle_slash_command('/bottom')
      expect(chat.message_stream.messages.size).to eq(initial_count)
    end
  end

  describe '/head' do
    before do
      %w[alpha beta gamma delta epsilon].each do |word|
        chat.message_stream.add_message(role: :user, content: word)
      end
    end

    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/head')
    end

    it 'returns :handled' do
      expect(chat.handle_slash_command('/head 3')).to eq(:handled)
    end

    it 'shows the first N messages by default (5)' do
      chat.message_stream.add_message(role: :user, content: 'extra')
      chat.handle_slash_command('/head')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('alpha')
      expect(content).to include('5')
    end

    it 'shows only the requested number of messages' do
      chat.handle_slash_command('/head 2')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('alpha')
      expect(content).to include('beta')
      expect(content).not_to include('gamma')
    end

    it 'includes role and truncated content in output' do
      chat.handle_slash_command('/head 1')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('[user]')
      expect(content).to include('alpha')
    end

    it 'shows "No messages." when stream is empty' do
      chat.message_stream.messages.clear
      chat.handle_slash_command('/head')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('No messages.')
    end
  end

  describe '/tail' do
    before do
      %w[alpha beta gamma delta epsilon].each do |word|
        chat.message_stream.add_message(role: :user, content: word)
      end
    end

    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/tail')
    end

    it 'returns :handled' do
      expect(chat.handle_slash_command('/tail 3')).to eq(:handled)
    end

    it 'shows the last N messages by default (5)' do
      chat.handle_slash_command('/tail')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('epsilon')
      expect(content).to include('5')
    end

    it 'shows only the requested number of tail messages' do
      chat.handle_slash_command('/tail 2')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('delta')
      expect(content).to include('epsilon')
      expect(content).not_to include('alpha')
    end

    it 'includes role and truncated content in output' do
      chat.handle_slash_command('/tail 1')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('[user]')
      expect(content).to include('epsilon')
    end

    it 'shows "No messages." when stream is empty' do
      chat.message_stream.messages.clear
      chat.handle_slash_command('/tail')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('No messages.')
    end
  end
end
