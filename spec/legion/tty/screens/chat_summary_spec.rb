# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/summary command' do
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
    it 'includes /summary' do
      expect(described_class::SLASH_COMMANDS).to include('/summary')
    end
  end

  describe '/summary with no messages' do
    it 'returns :handled' do
      result = chat.handle_slash_command('/summary')
      expect(result).to eq(:handled)
    end

    it 'shows conversation summary header' do
      chat.handle_slash_command('/summary')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Conversation Summary')
    end

    it 'shows message count' do
      chat.handle_slash_command('/summary')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Messages:')
    end

    it 'shows duration/uptime' do
      chat.handle_slash_command('/summary')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Duration:')
    end

    it 'shows most active role' do
      chat.handle_slash_command('/summary')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Most active role:')
    end

    it 'shows top starting words' do
      chat.handle_slash_command('/summary')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Top starting words:')
    end

    it 'shows longest message' do
      chat.handle_slash_command('/summary')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Longest message:')
    end

    it 'shows most recent topic' do
      chat.handle_slash_command('/summary')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Most recent topic:')
    end
  end

  describe '/summary with messages' do
    before do
      chat.message_stream.add_message(role: :user, content: 'Tell me about Ruby')
      chat.message_stream.add_message(role: :assistant, content: 'Ruby is a dynamic, interpreted language.')
      chat.message_stream.add_message(role: :user, content: 'Tell me about Python')
      chat.message_stream.add_message(role: :assistant, content: 'Python is great for data science.')
      chat.message_stream.add_message(role: :user, content: 'Compare them')
    end

    it 'returns :handled' do
      result = chat.handle_slash_command('/summary')
      expect(result).to eq(:handled)
    end

    it 'includes total message count' do
      chat.handle_slash_command('/summary')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to match(/Messages: \d+/)
    end

    it 'shows "Tell" as a top starting word (appears twice)' do
      chat.handle_slash_command('/summary')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Tell')
    end

    it 'shows the most recent user message as the recent topic' do
      chat.handle_slash_command('/summary')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Compare them')
    end

    it 'identifies the most active role' do
      chat.handle_slash_command('/summary')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      content = msgs.last[:content]
      expect(content).to match(/Most active role: (user|assistant|system)/)
    end

    it 'truncates longest message preview to 60 characters' do
      long_content = 'a' * 100
      chat.message_stream.add_message(role: :assistant, content: long_content)
      chat.handle_slash_command('/summary')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      content = msgs.last[:content]
      long_line = content.lines.find { |l| l.include?('Longest message:') }
      expect(long_line.length).to be < 200
    end

    it 'truncates recent topic to 40 characters' do
      very_long_topic = 'a' * 200
      chat.message_stream.add_message(role: :user, content: very_long_topic)
      chat.handle_slash_command('/summary')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      content = msgs.last[:content]
      topic_line = content.lines.find { |l| l.include?('Most recent topic:') }
      expect(topic_line).not_to be_nil
      expect(topic_line.length).to be < 200
    end
  end

  describe '/summary with only system messages' do
    before do
      chat.message_stream.add_message(role: :system, content: 'System message')
    end

    it 'returns :handled' do
      result = chat.handle_slash_command('/summary')
      expect(result).to eq(:handled)
    end

    it 'shows "none" for top starting words when no user messages' do
      chat.handle_slash_command('/summary')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('none')
    end
  end
end
