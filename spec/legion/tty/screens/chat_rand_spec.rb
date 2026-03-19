# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/rand command' do
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

  describe '/rand' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/rand')
    end

    it 'returns :handled' do
      expect(chat.handle_slash_command('/rand')).to eq(:handled)
    end

    it 'generates a float between 0 and 1 with no argument' do
      chat.handle_slash_command('/rand')
      content = chat.message_stream.messages.last[:content]
      expect(content).to match(/\ARandom: \d/)
      value = content.sub('Random: ', '').to_f
      expect(value).to be >= 0.0
      expect(value).to be < 1.0
    end

    it 'generates an integer in 0...N with numeric argument' do
      50.times do
        chat.handle_slash_command('/rand 10')
        content = chat.message_stream.messages.last[:content]
        value = content.sub('Random: ', '').to_i
        expect(value).to be >= 0
        expect(value).to be < 10
      end
    end

    it 'generates an integer within a range with N..M argument' do
      50.times do
        chat.handle_slash_command('/rand 5..15')
        content = chat.message_stream.messages.last[:content]
        value = content.sub('Random: ', '').to_i
        expect(value).to be >= 5
        expect(value).to be <= 15
      end
    end

    it 'shows usage for invalid argument' do
      chat.handle_slash_command('/rand abc')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Usage:')
    end

    it 'shows a result prefixed with "Random:"' do
      chat.handle_slash_command('/rand 100')
      content = chat.message_stream.messages.last[:content]
      expect(content).to start_with('Random:')
    end
  end
end
