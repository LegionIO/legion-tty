# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, 'tool call parsing' do
  let(:app) do
    config = { name: 'Test', provider: 'claude' }
    instance_double('App', llm_chat: nil, config: config).tap do |a|
      allow(a).to receive(:respond_to?).with(:llm_chat).and_return(false)
      allow(a).to receive(:respond_to?).with(:config).and_return(true)
      allow(a).to receive(:respond_to?).with(:screen_manager).and_return(false)
    end
  end

  let(:chat) { described_class.new(app, output: StringIO.new) }

  describe '#build_tool_call_parser' do
    it 'routes plain text to append_streaming' do
      chat.activate
      chat.message_stream.add_message(role: :assistant, content: '')
      parser = chat.send(:build_tool_call_parser)
      parser.feed('hello world')
      parser.flush
      expect(chat.message_stream.messages.last[:content]).to eq('hello world')
    end

    it 'routes tool_call blocks to add_tool_call' do
      chat.activate
      chat.message_stream.add_message(role: :assistant, content: '')
      parser = chat.send(:build_tool_call_parser)
      parser.feed('<tool_call>{"name": "search", "arguments": {"q": "test"}}</tool_call>')
      parser.flush

      tool_msg = chat.message_stream.messages.find { |m| m[:role] == :tool }
      expect(tool_msg).not_to be_nil
      expect(tool_msg[:tool_panel]).to be true
    end

    it 'handles mixed text and tool calls' do
      chat.activate
      chat.message_stream.add_message(role: :assistant, content: '')
      parser = chat.send(:build_tool_call_parser)
      parser.feed('Looking up... <tool_call>{"name": "ls", "arguments": {}}</tool_call> Done.')
      parser.flush

      messages = chat.message_stream.messages
      assistant_msg = messages.find { |m| m[:role] == :assistant }
      tool_msg = messages.find { |m| m[:role] == :tool }

      expect(assistant_msg[:content]).to include('Looking up...')
      expect(tool_msg).not_to be_nil
    end
  end
end
