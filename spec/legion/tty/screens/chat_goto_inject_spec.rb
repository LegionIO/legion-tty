# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/goto and /inject commands' do
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
    allow(app).to receive(:respond_to?).with(:hotkeys).and_return(false)
    allow(app).to receive(:respond_to?).with(:toggle_dashboard).and_return(false)
  end

  subject(:chat) { described_class.new(app, output: output, input_bar: input_bar) }

  # ── /goto ──────────────────────────────────────────────────────────────────

  describe 'SLASH_COMMANDS' do
    it 'includes /goto' do
      expect(described_class::SLASH_COMMANDS).to include('/goto')
    end

    it 'includes /inject' do
      expect(described_class::SLASH_COMMANDS).to include('/inject')
    end
  end

  describe '/goto with no argument' do
    it 'shows usage and returns :handled' do
      result = chat.handle_slash_command('/goto')
      expect(result).to eq(:handled)
      last = chat.message_stream.messages.last
      expect(last[:content]).to include('Usage: /goto')
    end
  end

  describe '/goto with non-numeric argument' do
    it 'shows usage and returns :handled' do
      result = chat.handle_slash_command('/goto abc')
      expect(result).to eq(:handled)
      last = chat.message_stream.messages.last
      expect(last[:content]).to include('Usage: /goto')
    end
  end

  describe '/goto with out-of-range index' do
    before do
      3.times { |i| chat.message_stream.add_message(role: :user, content: "msg #{i}") }
    end

    it 'shows out-of-range error and returns :handled' do
      result = chat.handle_slash_command('/goto 999')
      expect(result).to eq(:handled)
      last = chat.message_stream.messages.last
      expect(last[:content]).to include('out of range')
    end
  end

  describe '/goto with valid index' do
    before do
      5.times { |i| chat.message_stream.add_message(role: :user, content: "msg #{i}") }
    end

    it 'returns :handled' do
      expect(chat.handle_slash_command('/goto 0')).to eq(:handled)
    end

    it 'shows jumped-to confirmation message' do
      chat.handle_slash_command('/goto 0')
      last = chat.message_stream.messages.last
      expect(last[:content]).to match(/Jumped to message 0/)
    end

    it 'sets a positive scroll offset when jumping to message 0' do
      chat.handle_slash_command('/goto 0')
      expect(chat.message_stream.scroll_offset).to be > 0
    end

    it 'sets scroll offset to 0 when jumping to the last message' do
      total = chat.message_stream.messages.size
      chat.handle_slash_command("/goto #{total - 1}")
      expect(chat.message_stream.scroll_offset).to eq(0)
    end
  end

  # ── /inject ────────────────────────────────────────────────────────────────

  describe '/inject with no arguments' do
    it 'shows usage and returns :handled' do
      result = chat.handle_slash_command('/inject')
      expect(result).to eq(:handled)
      last = chat.message_stream.messages.last
      expect(last[:content]).to include('Usage: /inject')
    end
  end

  describe '/inject with invalid role' do
    it 'shows usage for unrecognised role' do
      result = chat.handle_slash_command('/inject robot hello there')
      expect(result).to eq(:handled)
      last = chat.message_stream.messages.last
      expect(last[:content]).to include('Usage: /inject')
    end
  end

  describe '/inject with no text' do
    it 'shows usage when text is missing' do
      result = chat.handle_slash_command('/inject user')
      expect(result).to eq(:handled)
      last = chat.message_stream.messages.last
      expect(last[:content]).to include('Usage: /inject')
    end
  end

  describe '/inject user <text>' do
    it 'returns :handled' do
      expect(chat.handle_slash_command('/inject user Hello world')).to eq(:handled)
    end

    it 'adds a message with role :user and the given content' do
      chat.handle_slash_command('/inject user Hello world')
      injected = chat.message_stream.messages.find { |m| m[:role] == :user && m[:content] == 'Hello world' }
      expect(injected).not_to be_nil
    end

    it 'shows confirmation with the injected role' do
      chat.handle_slash_command('/inject user Hello world')
      sys_msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(sys_msgs.last[:content]).to include('[user]')
    end
  end

  describe '/inject assistant <text>' do
    it 'adds a message with role :assistant' do
      chat.handle_slash_command('/inject assistant This is a synthetic reply')
      injected = chat.message_stream.messages.find { |m| m[:role] == :assistant }
      expect(injected).not_to be_nil
      expect(injected[:content]).to eq('This is a synthetic reply')
    end
  end

  describe '/inject system <text>' do
    it 'adds a message with role :system and the given text' do
      chat.handle_slash_command('/inject system Context reminder: be concise')
      injected = chat.message_stream.messages.find do |m|
        m[:role] == :system && m[:content] == 'Context reminder: be concise'
      end
      expect(injected).not_to be_nil
    end
  end

  describe '/inject updates message count' do
    it 'increments the message count after injection' do
      before_count = chat.message_stream.messages.size
      chat.handle_slash_command('/inject user count me')
      expect(chat.message_stream.messages.size).to be > before_count
    end
  end
end
