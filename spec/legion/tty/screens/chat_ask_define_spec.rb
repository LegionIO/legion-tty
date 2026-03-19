# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/ask and /define commands' do
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
    allow(app).to receive(:respond_to?).with(:config).and_return(true)
    allow(app).to receive(:respond_to?).with(:llm_chat).and_return(true)
    allow(app).to receive(:respond_to?).with(:screen_manager).and_return(true)
    allow(app).to receive(:respond_to?).with(:hotkeys).and_return(true)
    allow(app).to receive(:respond_to?).with(:toggle_dashboard).and_return(false)
  end

  subject(:chat) { described_class.new(app, output: output, input_bar: input_bar) }

  describe 'SLASH_COMMANDS registry' do
    it 'includes /ask' do
      expect(described_class::SLASH_COMMANDS).to include('/ask')
    end

    it 'includes /define' do
      expect(described_class::SLASH_COMMANDS).to include('/define')
    end
  end

  describe '#handle_ask' do
    before { allow(chat).to receive(:send_to_llm) }

    it 'shows usage when no question given' do
      result = chat.handle_slash_command('/ask')
      expect(result).to eq(:handled)
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to eq('Usage: /ask <question>')
    end

    it 'stores the original question as the user message' do
      chat.handle_slash_command('/ask what is RabbitMQ?')
      user_msgs = chat.message_stream.messages.select { |m| m[:role] == :user }
      expect(user_msgs.last[:content]).to eq('what is RabbitMQ?')
    end

    it 'sends the prefixed prompt to the LLM' do
      expect(chat).to receive(:send_to_llm)
        .with('Answer the following question concisely in one paragraph: what is RabbitMQ?')
      chat.handle_slash_command('/ask what is RabbitMQ?')
    end

    it 'returns :handled' do
      result = chat.handle_slash_command('/ask anything')
      expect(result).to eq(:handled)
    end

    it 'adds an empty assistant placeholder message' do
      chat.handle_slash_command('/ask something')
      assistant_msgs = chat.message_stream.messages.select { |m| m[:role] == :assistant }
      expect(assistant_msgs).not_to be_empty
    end
  end

  describe '#handle_define' do
    before { allow(chat).to receive(:send_to_llm) }

    it 'shows usage when no term given' do
      result = chat.handle_slash_command('/define')
      expect(result).to eq(:handled)
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to eq('Usage: /define <term>')
    end

    it 'stores the term as the user message' do
      chat.handle_slash_command('/define idempotent')
      user_msgs = chat.message_stream.messages.select { |m| m[:role] == :user }
      expect(user_msgs.last[:content]).to eq('idempotent')
    end

    it 'sends the define prompt to the LLM' do
      expect(chat).to receive(:send_to_llm)
        .with('Define the following term concisely: idempotent')
      chat.handle_slash_command('/define idempotent')
    end

    it 'returns :handled' do
      result = chat.handle_slash_command('/define anything')
      expect(result).to eq(:handled)
    end

    it 'adds an empty assistant placeholder message' do
      chat.handle_slash_command('/define something')
      assistant_msgs = chat.message_stream.messages.select { |m| m[:role] == :assistant }
      expect(assistant_msgs).not_to be_empty
    end
  end
end
