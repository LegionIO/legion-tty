# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/ago command' do
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

  describe '/ago' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/ago')
    end

    it 'returns :handled' do
      chat.message_stream.add_message(role: :user, content: 'hello')
      expect(chat.handle_slash_command('/ago 1')).to eq(:handled)
    end

    it 'shows the message content 1 ago by default' do
      chat.message_stream.add_message(role: :user, content: 'first message')
      chat.handle_slash_command('/ago 1')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('first message')
    end

    it 'includes the role in the output' do
      chat.message_stream.add_message(role: :user, content: 'from user')
      chat.handle_slash_command('/ago 1')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('user')
    end

    it 'includes the message index in the output' do
      chat.message_stream.add_message(role: :user, content: 'msg zero')
      chat.handle_slash_command('/ago 1')
      content = chat.message_stream.messages.last[:content]
      expect(content).to match(/#\d+/)
    end

    it 'shows correct message when N > 1' do
      chat.message_stream.add_message(role: :user, content: 'first')
      chat.message_stream.add_message(role: :assistant, content: 'second')
      chat.handle_slash_command('/ago 2')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('first')
    end

    it 'defaults to 1 when no N given' do
      chat.message_stream.add_message(role: :user, content: 'only message')
      chat.handle_slash_command('/ago')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('only message')
    end

    it 'shows an error when N exceeds message count' do
      chat.message_stream.add_message(role: :user, content: 'one message')
      chat.handle_slash_command('/ago 99')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('No message 99 ago')
    end

    it 'shows an error when N is zero' do
      chat.message_stream.add_message(role: :user, content: 'something')
      chat.handle_slash_command('/ago 0')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('No message 0 ago')
    end

    it 'shows an error when conversation is empty' do
      chat.handle_slash_command('/ago 1')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('No message 1 ago')
    end

    it 'includes how many messages ago in the output label' do
      chat.message_stream.add_message(role: :user, content: 'test')
      chat.handle_slash_command('/ago 1')
      content = chat.message_stream.messages.last[:content]
      expect(content).to match(/1 ago/)
    end
  end
end
