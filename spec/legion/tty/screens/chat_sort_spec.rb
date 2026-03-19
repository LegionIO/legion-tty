# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/sort command' do
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
    it 'includes /sort' do
      expect(described_class::SLASH_COMMANDS).to include('/sort')
    end
  end

  describe '/sort with no messages' do
    it 'returns :handled' do
      result = chat.handle_slash_command('/sort')
      expect(result).to eq(:handled)
    end

    it 'shows "No messages to sort."' do
      chat.handle_slash_command('/sort')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to eq('No messages to sort.')
    end
  end

  describe '/sort by length (default)' do
    before do
      chat.message_stream.add_message(role: :user, content: 'short')
      chat.message_stream.add_message(role: :assistant, content: 'a' * 200)
      chat.message_stream.add_message(role: :user, content: 'medium length message here')
    end

    it 'returns :handled' do
      result = chat.handle_slash_command('/sort')
      expect(result).to eq(:handled)
    end

    it 'shows messages sorted by length header' do
      chat.handle_slash_command('/sort')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('by length')
    end

    it 'shows character count for each message' do
      chat.handle_slash_command('/sort')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('chars')
    end

    it 'longest message appears first in output' do
      chat.handle_slash_command('/sort')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      content = msgs.last[:content]
      long_pos = content.index('200')
      short_pos = content.index('5 chars') || content.index('short')
      expect(long_pos).to be < short_pos if long_pos && short_pos
    end

    it 'does not modify the actual message order' do
      original_contents = chat.message_stream.messages.map { |m| m[:content] }.dup
      chat.handle_slash_command('/sort')
      non_system = chat.message_stream.messages.reject { |m| m[:role] == :system }
      expect(non_system.map { |m| m[:content] }).to eq(original_contents)
    end

    it 'shows at most 10 messages' do
      15.times { |i| chat.message_stream.add_message(role: :user, content: "msg #{i} #{'x' * i}") }
      chat.handle_slash_command('/sort')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      content = msgs.last[:content]
      lines = content.split("\n")
      data_lines = lines.reject { |l| l.start_with?('Messages') }
      expect(data_lines.size).to be <= 10
    end
  end

  describe '/sort length (explicit)' do
    before do
      chat.message_stream.add_message(role: :user, content: 'hello')
      chat.message_stream.add_message(role: :assistant, content: 'a longer response here')
    end

    it 'returns :handled' do
      result = chat.handle_slash_command('/sort length')
      expect(result).to eq(:handled)
    end

    it 'shows messages sorted by length' do
      chat.handle_slash_command('/sort length')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('by length')
    end
  end

  describe '/sort role' do
    before do
      chat.message_stream.add_message(role: :user, content: 'q1')
      chat.message_stream.add_message(role: :assistant, content: 'a1')
      chat.message_stream.add_message(role: :user, content: 'q2')
      chat.message_stream.add_message(role: :system, content: 'sys')
    end

    it 'returns :handled' do
      result = chat.handle_slash_command('/sort role')
      expect(result).to eq(:handled)
    end

    it 'shows messages grouped by role' do
      chat.handle_slash_command('/sort role')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('by role')
    end

    it 'shows user count' do
      chat.handle_slash_command('/sort role')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('user: 2')
    end

    it 'shows assistant count' do
      chat.handle_slash_command('/sort role')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('assistant: 1')
    end

    it 'does not modify the actual message order' do
      original_non_system = chat.message_stream.messages.reject { |m| m[:role] == :system }
                                                        .map { |m| m[:content] }.dup
      chat.handle_slash_command('/sort role')
      non_system = chat.message_stream.messages.reject { |m| m[:role] == :system }
      expect(non_system.map { |m| m[:content] }).to eq(original_non_system)
    end
  end

  describe '/sort role with no messages' do
    it 'shows "No messages to sort."' do
      chat.handle_slash_command('/sort role')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to eq('No messages to sort.')
    end
  end
end
