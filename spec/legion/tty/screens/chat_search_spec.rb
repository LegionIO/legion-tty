# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, 'search' do
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

  describe '/search' do
    it 'requires a query argument' do
      chat = described_class.new(app, output: output, input_bar: input_bar)
      result = chat.handle_slash_command('/search')
      expect(result).to eq(:handled)
      expect(chat.message_stream.messages.last[:content]).to include('Usage:')
    end

    it 'finds matching messages' do
      chat = described_class.new(app, output: output, input_bar: input_bar)
      chat.message_stream.add_message(role: :user, content: 'hello world')
      chat.message_stream.add_message(role: :assistant, content: 'goodbye world')
      result = chat.handle_slash_command('/search hello')
      expect(result).to eq(:handled)
      expect(chat.message_stream.messages.last[:content]).to include('1 message(s)')
    end

    it 'reports no results' do
      chat = described_class.new(app, output: output, input_bar: input_bar)
      chat.message_stream.add_message(role: :user, content: 'hello')
      result = chat.handle_slash_command('/search zzz')
      expect(result).to eq(:handled)
      expect(chat.message_stream.messages.last[:content]).to include('No messages matching')
    end

    it 'searches case-insensitively' do
      chat = described_class.new(app, output: output, input_bar: input_bar)
      chat.message_stream.add_message(role: :user, content: 'Hello World')
      result = chat.handle_slash_command('/search hello')
      expect(result).to eq(:handled)
      expect(chat.message_stream.messages.last[:content]).to include('1 message(s)')
    end
  end
end
