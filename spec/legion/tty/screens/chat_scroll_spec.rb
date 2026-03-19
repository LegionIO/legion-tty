# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/scroll command' do
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
    it 'includes /scroll' do
      expect(described_class::SLASH_COMMANDS).to include('/scroll')
    end
  end

  describe '/scroll with no arguments' do
    it 'returns :handled' do
      result = chat.handle_slash_command('/scroll')
      expect(result).to eq(:handled)
    end

    it 'shows current scroll position' do
      chat.handle_slash_command('/scroll')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Scroll position:')
    end

    it 'includes offset in output' do
      chat.handle_slash_command('/scroll')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('offset=')
    end

    it 'includes messages count in output' do
      chat.handle_slash_command('/scroll')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('messages=')
    end
  end

  describe '/scroll top' do
    before do
      5.times { |i| chat.message_stream.add_message(role: :user, content: "message #{i}") }
    end

    it 'returns :handled' do
      result = chat.handle_slash_command('/scroll top')
      expect(result).to eq(:handled)
    end

    it 'shows "Scrolled to top."' do
      chat.handle_slash_command('/scroll top')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to eq('Scrolled to top.')
    end

    it 'sets a large scroll offset' do
      chat.handle_slash_command('/scroll top')
      expect(chat.message_stream.scroll_offset).to be > 0
    end
  end

  describe '/scroll bottom' do
    before do
      5.times { |i| chat.message_stream.add_message(role: :user, content: "message #{i}") }
      chat.message_stream.scroll_up(50)
    end

    it 'returns :handled' do
      result = chat.handle_slash_command('/scroll bottom')
      expect(result).to eq(:handled)
    end

    it 'shows "Scrolled to bottom."' do
      chat.handle_slash_command('/scroll bottom')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to eq('Scrolled to bottom.')
    end

    it 'resets scroll offset to 0' do
      chat.handle_slash_command('/scroll bottom')
      expect(chat.message_stream.scroll_offset).to eq(0)
    end
  end

  describe '/scroll N (message index)' do
    before do
      chat.message_stream.add_message(role: :user, content: 'message zero')
      chat.message_stream.add_message(role: :assistant, content: 'message one')
      chat.message_stream.add_message(role: :user, content: 'message two')
    end

    it 'returns :handled for valid index' do
      result = chat.handle_slash_command('/scroll 1')
      expect(result).to eq(:handled)
    end

    it 'shows "Scrolled to message N." for valid index' do
      chat.handle_slash_command('/scroll 1')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to match(/Scrolled to message \d+\./)
    end

    it 'shows error for out-of-range index' do
      chat.handle_slash_command('/scroll 999')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Invalid index')
    end

    it 'shows error for negative index' do
      chat.handle_slash_command('/scroll -1')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Invalid index')
    end

    it 'shows usage hint in error message' do
      chat.handle_slash_command('/scroll 999')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('/scroll')
    end
  end
end
