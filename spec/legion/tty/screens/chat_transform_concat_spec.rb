# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/transform and /concat commands' do
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

  describe '/transform' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/transform')
    end

    it 'returns :handled' do
      chat.message_stream.add_message(role: :assistant, content: 'hello')
      expect(chat.handle_slash_command('/transform upcase')).to eq(:handled)
    end

    it 'shows usage when no operation is given' do
      chat.handle_slash_command('/transform')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Usage:')
    end

    it 'shows usage for an unknown operation' do
      chat.handle_slash_command('/transform explode')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Usage:')
    end

    it 'applies upcase to last assistant message' do
      chat.message_stream.add_message(role: :assistant, content: 'hello world')
      chat.handle_slash_command('/transform upcase')
      msg = chat.message_stream.messages.find { |m| m[:role] == :assistant }
      expect(msg[:content]).to eq('HELLO WORLD')
    end

    it 'applies downcase to last assistant message' do
      chat.message_stream.add_message(role: :assistant, content: 'HELLO WORLD')
      chat.handle_slash_command('/transform downcase')
      msg = chat.message_stream.messages.find { |m| m[:role] == :assistant }
      expect(msg[:content]).to eq('hello world')
    end

    it 'applies reverse to last assistant message' do
      chat.message_stream.add_message(role: :assistant, content: 'abc')
      chat.handle_slash_command('/transform reverse')
      msg = chat.message_stream.messages.find { |m| m[:role] == :assistant }
      expect(msg[:content]).to eq('cba')
    end

    it 'applies strip to last assistant message' do
      chat.message_stream.add_message(role: :assistant, content: '  hello  ')
      chat.handle_slash_command('/transform strip')
      msg = chat.message_stream.messages.find { |m| m[:role] == :assistant }
      expect(msg[:content]).to eq('hello')
    end

    it 'applies squeeze to last assistant message' do
      chat.message_stream.add_message(role: :assistant, content: 'heeello')
      chat.handle_slash_command('/transform squeeze')
      msg = chat.message_stream.messages.find { |m| m[:role] == :assistant }
      expect(msg[:content]).to eq('helo')
    end

    it 'shows error when no assistant message exists' do
      chat.handle_slash_command('/transform upcase')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('No assistant message')
    end

    it 'transforms only the last assistant message' do
      chat.message_stream.add_message(role: :assistant, content: 'first')
      chat.message_stream.add_message(role: :assistant, content: 'second')
      chat.handle_slash_command('/transform upcase')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :assistant }
      expect(msgs[0][:content]).to eq('first')
      expect(msgs[1][:content]).to eq('SECOND')
    end

    it 'shows a confirmation message after transforming' do
      chat.message_stream.add_message(role: :assistant, content: 'hello')
      chat.handle_slash_command('/transform upcase')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('upcase')
    end
  end

  describe '/concat' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/concat')
    end

    it 'returns :handled' do
      chat.message_stream.add_message(role: :assistant, content: 'hello')
      expect(chat.handle_slash_command('/concat')).to eq(:handled)
    end

    it 'shows error when no assistant messages exist' do
      chat.handle_slash_command('/concat')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('No assistant messages')
    end

    it 'adds combined content as a new system message' do
      chat.message_stream.add_message(role: :assistant, content: 'first')
      chat.message_stream.add_message(role: :assistant, content: 'second')
      chat.handle_slash_command('/concat')
      system_msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      combined_msg = system_msgs.find { |m| m[:content].include?('first') && m[:content].include?('second') }
      expect(combined_msg).not_to be_nil
    end

    it 'joins assistant messages with double newline' do
      chat.message_stream.add_message(role: :assistant, content: 'part one')
      chat.message_stream.add_message(role: :assistant, content: 'part two')
      chat.handle_slash_command('/concat')
      system_msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      combined_msg = system_msgs.find { |m| m[:content].include?('part one') }
      expect(combined_msg[:content]).to eq("part one\n\npart two")
    end

    it 'reports the count of concatenated messages' do
      chat.message_stream.add_message(role: :assistant, content: 'a')
      chat.message_stream.add_message(role: :assistant, content: 'b')
      chat.message_stream.add_message(role: :assistant, content: 'c')
      chat.handle_slash_command('/concat')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('3')
    end

    it 'works with a single assistant message' do
      chat.message_stream.add_message(role: :assistant, content: 'only one')
      chat.handle_slash_command('/concat')
      system_msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      combined_msg = system_msgs.find { |m| m[:content] == 'only one' }
      expect(combined_msg).not_to be_nil
    end

    it 'does not modify the original assistant messages' do
      chat.message_stream.add_message(role: :assistant, content: 'unchanged')
      chat.handle_slash_command('/concat')
      original = chat.message_stream.messages.find { |m| m[:role] == :assistant }
      expect(original[:content]).to eq('unchanged')
    end
  end
end
