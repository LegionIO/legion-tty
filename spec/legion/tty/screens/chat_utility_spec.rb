# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, 'utility commands' do
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
    allow(app).to receive(:respond_to?).with(:hotkeys).and_return(true)
    allow(app).to receive(:respond_to?).with(:toggle_dashboard).and_return(false)
  end

  describe '/compact' do
    it 'does nothing when already compact' do
      chat = described_class.new(app, output: output, input_bar: input_bar)
      chat.message_stream.add_message(role: :user, content: 'hi')
      result = chat.handle_slash_command('/compact')
      expect(result).to eq(:handled)
      expect(chat.message_stream.messages.last[:content]).to include('already compact')
    end

    it 'removes older messages beyond keep count' do
      chat = described_class.new(app, output: output, input_bar: input_bar)
      20.times { |i| chat.message_stream.add_message(role: :user, content: "msg #{i}") }
      result = chat.handle_slash_command('/compact 3')
      expect(result).to eq(:handled)
      expect(chat.message_stream.messages.last[:content]).to include('Compacted')
    end

    it 'defaults to keeping 5 pairs' do
      chat = described_class.new(app, output: output, input_bar: input_bar)
      30.times { |i| chat.message_stream.add_message(role: :user, content: "msg #{i}") }
      result = chat.handle_slash_command('/compact')
      expect(result).to eq(:handled)
      expect(chat.message_stream.messages.last[:content]).to include('Compacted')
    end
  end

  describe '/copy' do
    it 'reports no assistant message when none exists' do
      chat = described_class.new(app, output: output, input_bar: input_bar)
      result = chat.handle_slash_command('/copy')
      expect(result).to eq(:handled)
      expect(chat.message_stream.messages.last[:content]).to include('No assistant message')
    end

    it 'copies last assistant message' do
      chat = described_class.new(app, output: output, input_bar: input_bar)
      chat.message_stream.add_message(role: :assistant, content: 'hello world')
      allow(IO).to receive(:popen).and_return(nil)
      result = chat.handle_slash_command('/copy')
      expect(result).to eq(:handled)
      expect(chat.message_stream.messages.last[:content]).to include('Copied')
    end
  end

  describe '/diff' do
    it 'reports no session loaded when none was' do
      chat = described_class.new(app, output: output, input_bar: input_bar)
      result = chat.handle_slash_command('/diff')
      expect(result).to eq(:handled)
      expect(chat.message_stream.messages.last[:content]).to include('No session was loaded')
    end
  end
end
