# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/chain command' do
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
    it 'includes /chain' do
      expect(described_class::SLASH_COMMANDS).to include('/chain')
    end
  end

  describe '/chain with no arguments' do
    it 'returns :handled' do
      result = chat.handle_slash_command('/chain')
      expect(result).to eq(:handled)
    end

    it 'shows usage message' do
      chat.handle_slash_command('/chain')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Usage: /chain')
    end

    it 'shows pipe separator example in usage' do
      chat.handle_slash_command('/chain')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('|')
    end
  end

  describe '/chain without LLM configured' do
    it 'returns :handled' do
      result = chat.handle_slash_command('/chain hello | world')
      expect(result).to eq(:handled)
    end

    it 'shows LLM not configured message' do
      chat.handle_slash_command('/chain hello | world')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('LLM not configured')
    end
  end

  describe '/chain with LLM available' do
    let(:mock_llm) { double('llm_chat') }

    before do
      allow(app).to receive(:llm_chat).and_return(mock_llm)
      allow(mock_llm).to receive(:respond_to?).and_return(false)
      allow(mock_llm).to receive(:ask).and_return(double('response', input_tokens: 10, output_tokens: 20,
                                                                     model: 'claude'))
      chat.instance_variable_set(:@llm_chat, mock_llm)
      allow(chat).to receive(:send_to_llm)
    end

    it 'returns :handled' do
      result = chat.handle_slash_command('/chain tell me a joke | explain it')
      expect(result).to eq(:handled)
    end

    it 'adds user messages for each prompt' do
      chat.handle_slash_command('/chain first prompt | second prompt')
      user_msgs = chat.message_stream.messages.select { |m| m[:role] == :user }
      contents = user_msgs.map { |m| m[:content] }
      expect(contents).to include('first prompt')
      expect(contents).to include('second prompt')
    end

    it 'shows chain complete message with count' do
      chat.handle_slash_command('/chain one | two | three')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Chain complete: 3 prompts sent')
    end

    it 'uses singular "prompt" when only one prompt sent' do
      chat.handle_slash_command('/chain just one')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('1 prompt sent')
      expect(msgs.last[:content]).not_to include('prompts sent')
    end

    it 'handles extra whitespace around pipe separators' do
      chat.handle_slash_command('/chain   hello   |   world   ')
      user_msgs = chat.message_stream.messages.select { |m| m[:role] == :user }
      contents = user_msgs.map { |m| m[:content] }
      expect(contents).to include('hello')
      expect(contents).to include('world')
    end

    it 'calls send_to_llm for each prompt' do
      expect(chat).to receive(:send_to_llm).twice
      chat.handle_slash_command('/chain alpha | beta')
    end
  end

  describe '/chain with only pipe separators (empty prompts)' do
    let(:mock_llm) { double('llm_chat') }

    before do
      chat.instance_variable_set(:@llm_chat, mock_llm)
    end

    it 'shows usage when all prompts are empty' do
      chat.handle_slash_command('/chain | | |')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Usage: /chain')
    end
  end
end
