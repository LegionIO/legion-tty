# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/color command' do
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
    it 'includes /color' do
      expect(described_class::SLASH_COMMANDS).to include('/color')
    end
  end

  describe '/color initialization' do
    it 'message_stream starts with colorize true' do
      expect(chat.message_stream.colorize).to be true
    end
  end

  describe '/color off' do
    it 'returns :handled' do
      expect(chat.handle_slash_command('/color off')).to eq(:handled)
    end

    it 'sets colorize to false on message_stream' do
      chat.handle_slash_command('/color off')
      expect(chat.message_stream.colorize).to be false
    end

    it 'shows "Color output OFF" confirmation' do
      chat.handle_slash_command('/color off')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('Color output OFF.')
    end
  end

  describe '/color on' do
    before { chat.message_stream.colorize = false }

    it 'sets colorize to true on message_stream' do
      chat.handle_slash_command('/color on')
      expect(chat.message_stream.colorize).to be true
    end

    it 'shows "Color output ON" confirmation' do
      chat.handle_slash_command('/color on')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('Color output ON.')
    end
  end

  describe '/color (toggle)' do
    it 'toggles colorize from true to false' do
      chat.handle_slash_command('/color')
      expect(chat.message_stream.colorize).to be false
    end

    it 'toggles colorize from false to true' do
      chat.message_stream.colorize = false
      chat.handle_slash_command('/color')
      expect(chat.message_stream.colorize).to be true
    end
  end
end

RSpec.describe Legion::TTY::Components::MessageStream, 'colorize rendering' do
  subject(:stream) { described_class.new }

  describe '#colorize' do
    it 'initializes to true' do
      expect(stream.colorize).to be true
    end

    it 'can be set to false via attr_accessor' do
      stream.colorize = false
      expect(stream.colorize).to be false
    end
  end

  describe 'render without color' do
    before do
      stream.add_message(role: :user, content: 'hello')
    end

    it 'strips ANSI escape codes when colorize is false' do
      stream.colorize = false
      lines = stream.render(width: 80, height: 20)
      combined = lines.join("\n")
      expect(combined).not_to match(/\e\[/)
    end

    it 'preserves content text when colorize is false' do
      stream.colorize = false
      lines = stream.render(width: 80, height: 20)
      combined = lines.join("\n")
      expect(combined).to include('hello')
    end

    it 'includes ANSI codes when colorize is true' do
      stream.colorize = true
      lines = stream.render(width: 80, height: 20)
      combined = lines.join("\n")
      expect(combined).to match(/\e\[/)
    end
  end
end
