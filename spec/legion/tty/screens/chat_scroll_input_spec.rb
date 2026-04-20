# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, 'scroll input handling' do
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

  before do
    10.times { |i| chat.message_stream.add_message(role: :user, content: "message #{i}") }
  end

  describe ':scroll_up (mouse wheel up)' do
    it 'returns :handled' do
      expect(chat.handle_input(:scroll_up)).to eq(:handled)
    end

    it 'increases scroll_offset by 3' do
      chat.handle_input(:scroll_up)
      expect(chat.message_stream.scroll_offset).to eq(3)
    end
  end

  describe ':scroll_down (mouse wheel down)' do
    before { chat.message_stream.scroll_up(10) }

    it 'returns :handled' do
      expect(chat.handle_input(:scroll_down)).to eq(:handled)
    end

    it 'decreases scroll_offset by 3' do
      chat.handle_input(:scroll_down)
      expect(chat.message_stream.scroll_offset).to eq(7)
    end
  end

  describe ':ctrl_b (half-page up)' do
    it 'returns :handled' do
      expect(chat.handle_input(:ctrl_b)).to eq(:handled)
    end

    it 'scrolls up by approximately half a page' do
      chat.handle_input(:ctrl_b)
      expect(chat.message_stream.scroll_offset).to be > 0
    end
  end

  describe ':ctrl_f (half-page down)' do
    before { chat.message_stream.scroll_up(20) }

    it 'returns :handled' do
      expect(chat.handle_input(:ctrl_f)).to eq(:handled)
    end

    it 'scrolls down by approximately half a page' do
      initial = chat.message_stream.scroll_offset
      chat.handle_input(:ctrl_f)
      expect(chat.message_stream.scroll_offset).to be < initial
    end
  end

  describe ':home (jump to top)' do
    it 'returns :handled' do
      expect(chat.handle_input(:home)).to eq(:handled)
    end

    it 'sets a large scroll_offset' do
      chat.handle_input(:home)
      expect(chat.message_stream.scroll_offset).to be > 0
    end
  end

  describe ':end (jump to bottom)' do
    before { chat.message_stream.scroll_up(20) }

    it 'returns :handled' do
      expect(chat.handle_input(:end)).to eq(:handled)
    end

    it 'resets scroll_offset to 0' do
      chat.handle_input(:end)
      expect(chat.message_stream.scroll_offset).to eq(0)
    end
  end

  describe 'unrecognized keys' do
    it 'returns :pass' do
      expect(chat.handle_input(:unknown)).to eq(:pass)
    end
  end

  describe ':page_up' do
    it 'scrolls up by half a page' do
      chat.handle_input(:page_up)
      expect(chat.message_stream.scroll_offset).to be > 0
    end
  end

  describe ':page_down' do
    before { chat.message_stream.scroll_up(100) }

    it 'scrolls down by half a page' do
      initial = chat.message_stream.scroll_offset
      chat.handle_input(:page_down)
      expect(chat.message_stream.scroll_offset).to be < initial
    end
  end
end
