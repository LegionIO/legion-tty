# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/echo and /env commands' do
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

  # ---------------------------------------------------------------------------
  # /echo
  # ---------------------------------------------------------------------------
  describe '/echo' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/echo')
    end

    it 'returns :handled' do
      expect(chat.handle_slash_command('/echo hello')).to eq(:handled)
    end

    it 'adds the given text as a system message' do
      chat.handle_slash_command('/echo --- Section Break ---')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to eq('--- Section Break ---')
    end

    it 'preserves multi-word text verbatim' do
      chat.handle_slash_command('/echo Note: switching topics now')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to eq('Note: switching topics now')
    end

    it 'shows usage when called with no text' do
      chat.handle_slash_command('/echo')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Usage:')
    end

    it 'shows usage when called with only whitespace' do
      chat.handle_slash_command('/echo   ')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Usage:')
    end

    it 'does not forward the text to the LLM' do
      expect(chat).not_to receive(:send_to_llm)
      chat.handle_slash_command('/echo just a note')
    end
  end

  # ---------------------------------------------------------------------------
  # /env
  # ---------------------------------------------------------------------------
  describe '/env' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/env')
    end

    it 'returns :handled' do
      expect(chat.handle_slash_command('/env')).to eq(:handled)
    end

    it 'shows the Ruby version' do
      chat.handle_slash_command('/env')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include(RUBY_VERSION)
    end

    it 'shows the Ruby platform' do
      chat.handle_slash_command('/env')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include(RUBY_PLATFORM)
    end

    it 'shows the process PID' do
      chat.handle_slash_command('/env')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include(Process.pid.to_s)
    end

    it 'shows the legion-tty version' do
      chat.handle_slash_command('/env')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include(Legion::TTY::VERSION)
    end

    it 'shows terminal dimensions' do
      allow(chat).to receive(:terminal_width).and_return(120)
      allow(chat).to receive(:terminal_height).and_return(40)
      chat.handle_slash_command('/env')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('120x40')
    end

    it 'reports as a system message' do
      chat.handle_slash_command('/env')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last).not_to be_nil
    end
  end
end
