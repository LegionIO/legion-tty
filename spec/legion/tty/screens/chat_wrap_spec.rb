# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/wrap command' do
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
    it 'includes /wrap' do
      expect(described_class::SLASH_COMMANDS).to include('/wrap')
    end
  end

  describe '/wrap N' do
    it 'returns :handled' do
      expect(chat.handle_slash_command('/wrap 80')).to eq(:handled)
    end

    it 'sets wrap_width on message_stream' do
      chat.handle_slash_command('/wrap 80')
      expect(chat.message_stream.wrap_width).to eq(80)
    end

    it 'shows confirmation message' do
      chat.handle_slash_command('/wrap 80')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('Word wrap set to 80 columns.')
    end

    it 'accepts any width >= 20' do
      chat.handle_slash_command('/wrap 120')
      expect(chat.message_stream.wrap_width).to eq(120)
    end

    it 'rejects widths below 20' do
      chat.handle_slash_command('/wrap 10')
      expect(chat.message_stream.wrap_width).to be_nil
    end

    it 'shows usage message for invalid arg' do
      chat.handle_slash_command('/wrap 10')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('Usage: /wrap [N|off]')
    end

    it 'rejects zero' do
      chat.handle_slash_command('/wrap 0')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('Usage: /wrap [N|off]')
    end
  end

  describe '/wrap off' do
    it 'disables wrapping' do
      chat.message_stream.wrap_width = 80
      chat.handle_slash_command('/wrap off')
      expect(chat.message_stream.wrap_width).to be_nil
    end

    it 'shows confirmation after disabling' do
      chat.handle_slash_command('/wrap off')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('Word wrap disabled.')
    end
  end

  describe '/wrap (no arg)' do
    it 'shows "off" when wrap_width is nil' do
      chat.handle_slash_command('/wrap')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('Wrap: off')
    end

    it 'shows current width when wrap_width is set' do
      chat.message_stream.wrap_width = 80
      chat.handle_slash_command('/wrap')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('Wrap: 80 columns')
    end
  end
end

RSpec.describe Legion::TTY::Components::MessageStream, 'wrap_width rendering' do
  subject(:stream) { described_class.new }

  describe '#wrap_width' do
    it 'initializes to nil' do
      expect(stream.wrap_width).to be_nil
    end

    it 'can be set via attr_accessor' do
      stream.wrap_width = 80
      expect(stream.wrap_width).to eq(80)
    end
  end

  describe 'render with wrap_width' do
    it 'uses wrap_width instead of passed width when set' do
      stream.wrap_width = 40
      stream.add_message(role: :assistant, content: 'hello')
      # render with width: 200 but wrap_width 40 — should render without error
      lines = stream.render(width: 200, height: 20)
      expect(lines).to be_an(Array)
    end

    it 'uses passed width when wrap_width is nil' do
      stream.wrap_width = nil
      stream.add_message(role: :assistant, content: 'hello')
      lines = stream.render(width: 80, height: 20)
      expect(lines).to be_an(Array)
    end
  end
end
