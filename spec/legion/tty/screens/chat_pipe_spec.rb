# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/pipe command' do
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

  describe '/pipe in SLASH_COMMANDS' do
    it 'includes /pipe in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/pipe')
    end
  end

  describe '/pipe with no args' do
    it 'returns :handled' do
      expect(chat.handle_slash_command('/pipe')).to eq(:handled)
    end

    it 'shows usage message' do
      chat.handle_slash_command('/pipe')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Usage:')
    end
  end

  describe '/pipe with no assistant message' do
    it 'returns :handled' do
      expect(chat.handle_slash_command('/pipe cat')).to eq(:handled)
    end

    it 'shows no-message error' do
      chat.handle_slash_command('/pipe cat')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('No assistant message')
    end
  end

  describe '/pipe with assistant message present' do
    before do
      chat.message_stream.add_message(role: :assistant, content: "hello world\nfoo bar")
    end

    it 'returns :handled' do
      expect(chat.handle_slash_command('/pipe cat')).to eq(:handled)
    end

    it 'pipes content through the command and shows result' do
      chat.handle_slash_command('/pipe cat')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('hello world')
    end

    it 'includes the command name in the output header' do
      chat.handle_slash_command('/pipe cat')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('cat')
    end

    it 'counts words via wc -w' do
      chat.handle_slash_command('/pipe wc -w')
      content = chat.message_stream.messages.last[:content]
      expect(content).to match(/\d+/)
    end

    it 'pipes only the last assistant message' do
      chat.message_stream.add_message(role: :assistant, content: 'second response only')
      chat.handle_slash_command('/pipe cat')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('second response only')
      expect(content).not_to include('hello world')
    end
  end

  describe '/pipe with a failing command' do
    before do
      chat.message_stream.add_message(role: :assistant, content: 'some content')
    end

    it 'returns :handled on error' do
      expect(chat.handle_slash_command('/pipe false')).to eq(:handled)
    end

    it 'shows a pipe error message on bad command' do
      result = chat.handle_slash_command('/pipe nonexistent_command_xyz_abc_123')
      expect(result).to eq(:handled)
      content = chat.message_stream.messages.last[:content]
      expect(content).to match(/pipe.*error|error|No such file/i)
    end
  end
end
