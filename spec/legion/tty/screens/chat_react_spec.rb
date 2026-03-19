# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/react command' do
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

  describe '/react' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/react')
    end

    it 'returns :handled' do
      chat.message_stream.add_message(role: :assistant, content: 'hello')
      expect(chat.handle_slash_command('/react 👍')).to eq(:handled)
    end

    it 'shows usage when no emoji given' do
      chat.handle_slash_command('/react')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Usage:')
    end

    it 'adds reaction to last assistant message' do
      chat.message_stream.add_message(role: :assistant, content: 'response')
      chat.handle_slash_command('/react 🔥')
      msg = chat.message_stream.messages.find { |m| m[:role] == :assistant }
      expect(msg[:reactions]).to include('🔥')
    end

    it 'shows confirmation message after adding reaction' do
      chat.message_stream.add_message(role: :assistant, content: 'response')
      chat.handle_slash_command('/react 👍')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('👍')
      expect(content).to include('added')
    end

    it 'reports error when no assistant message exists' do
      chat.handle_slash_command('/react 👍')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('No message to react to.')
    end

    it 'adds reaction to message at specific index' do
      chat.message_stream.add_message(role: :user, content: 'user question')
      chat.message_stream.add_message(role: :assistant, content: 'assistant answer')
      chat.handle_slash_command('/react 0 ❤️')
      msg = chat.message_stream.messages[0]
      expect(msg[:reactions]).to include('❤️')
    end

    it 'allows multiple reactions on the same message' do
      chat.message_stream.add_message(role: :assistant, content: 'response')
      chat.handle_slash_command('/react 👍')
      chat.handle_slash_command('/react ❤️')
      msg = chat.message_stream.messages.find { |m| m[:role] == :assistant }
      expect(msg[:reactions]).to include('👍', '❤️')
    end

    it 'reports error for out-of-range index' do
      chat.handle_slash_command('/react 99 👍')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('No message to react to.')
    end
  end

  describe 'MessageStream reaction rendering' do
    it 'appends reaction line to assistant message lines when reactions present' do
      stream = Legion::TTY::Components::MessageStream.new
      stream.add_message(role: :assistant, content: 'hello')
      stream.messages.last[:reactions] = ['👍']
      lines = stream.render(width: 80, height: 50)
      reaction_line = lines.find { |l| l.include?('👍') }
      expect(reaction_line).not_to be_nil
    end

    it 'does not show reaction line when no reactions' do
      stream = Legion::TTY::Components::MessageStream.new
      stream.add_message(role: :assistant, content: 'hello')
      lines = stream.render(width: 80, height: 50)
      expect(lines.any? { |l| l.include?('[') && l.include?(']') }).to be false
    end
  end
end
