# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/tag and /tags commands' do
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

  describe '/tag' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/tag')
    end

    it 'returns :handled' do
      chat.message_stream.add_message(role: :assistant, content: 'response')
      expect(chat.handle_slash_command('/tag important')).to eq(:handled)
    end

    it 'shows usage when no label given' do
      chat.handle_slash_command('/tag')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Usage:')
    end

    it 'adds tag to the last assistant message' do
      chat.message_stream.add_message(role: :assistant, content: 'response')
      chat.handle_slash_command('/tag important')
      msg = chat.message_stream.messages.find { |m| m[:role] == :assistant }
      expect(msg[:tags]).to include('important')
    end

    it 'shows confirmation after tagging' do
      chat.message_stream.add_message(role: :assistant, content: 'response')
      chat.handle_slash_command('/tag interesting')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('interesting')
      expect(content).to include('added')
    end

    it 'reports error when no assistant message exists' do
      chat.handle_slash_command('/tag important')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('No message to tag.')
    end

    it 'tags message at a specific index' do
      chat.message_stream.add_message(role: :user, content: 'user question')
      chat.message_stream.add_message(role: :assistant, content: 'assistant answer')
      chat.handle_slash_command('/tag 0 question')
      msg = chat.message_stream.messages[0]
      expect(msg[:tags]).to include('question')
    end

    it 'deduplicates tags on the same message' do
      chat.message_stream.add_message(role: :assistant, content: 'response')
      chat.handle_slash_command('/tag important')
      chat.handle_slash_command('/tag important')
      msg = chat.message_stream.messages.find { |m| m[:role] == :assistant }
      expect(msg[:tags].count('important')).to eq(1)
    end

    it 'allows multiple distinct tags on one message' do
      chat.message_stream.add_message(role: :assistant, content: 'response')
      chat.handle_slash_command('/tag alpha')
      chat.handle_slash_command('/tag beta')
      msg = chat.message_stream.messages.find { |m| m[:role] == :assistant }
      expect(msg[:tags]).to include('alpha', 'beta')
    end

    it 'reports error for out-of-range index' do
      chat.handle_slash_command('/tag 99 label')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('No message to tag.')
    end
  end

  describe '/tags' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/tags')
    end

    it 'returns :handled' do
      expect(chat.handle_slash_command('/tags')).to eq(:handled)
    end

    it 'shows "No tagged messages." when no messages have tags' do
      chat.handle_slash_command('/tags')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('No tagged messages.')
    end

    it 'lists all unique tags with message counts' do
      chat.message_stream.add_message(role: :assistant, content: 'response one')
      chat.message_stream.messages.last[:tags] = %w[alpha beta]
      chat.message_stream.add_message(role: :assistant, content: 'response two')
      chat.message_stream.messages.last[:tags] = ['alpha']
      chat.handle_slash_command('/tags')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('#alpha')
      expect(content).to include('#beta')
      expect(content).to include('2')
    end

    it 'filters messages by tag when label given' do
      chat.message_stream.add_message(role: :assistant, content: 'tagged response')
      chat.message_stream.messages.last[:tags] = ['mytag']
      chat.message_stream.add_message(role: :assistant, content: 'untagged response')
      chat.handle_slash_command('/tags mytag')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('tagged response')
      expect(content).not_to include('untagged response')
    end

    it 'shows "No messages tagged" when filter finds nothing' do
      chat.handle_slash_command('/tags nonexistent')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('#nonexistent')
      expect(content).to include('No messages tagged')
    end

    it 'shows message count in filtered results header' do
      chat.message_stream.add_message(role: :assistant, content: 'response one')
      chat.message_stream.messages.last[:tags] = ['work']
      chat.message_stream.add_message(role: :assistant, content: 'response two')
      chat.message_stream.messages.last[:tags] = ['work']
      chat.handle_slash_command('/tags work')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('2')
    end
  end
end
