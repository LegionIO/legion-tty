# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/retry command' do
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
    it 'includes /retry' do
      expect(described_class::SLASH_COMMANDS).to include('/retry')
    end
  end

  describe '/retry with no prior input' do
    it 'returns :handled' do
      result = chat.handle_slash_command('/retry')
      expect(result).to eq(:handled)
    end

    it 'adds "Nothing to retry." system message when no prior input' do
      chat.handle_slash_command('/retry')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to eq('Nothing to retry.')
    end
  end

  describe '/retry with prior user input' do
    before do
      allow(chat).to receive(:send_to_llm)
      chat.instance_variable_set(:@last_user_input, 'tell me a joke')
    end

    it 'returns :handled' do
      result = chat.handle_slash_command('/retry')
      expect(result).to eq(:handled)
    end

    it 'calls send_to_llm with the last user input' do
      expect(chat).to receive(:send_to_llm).with('tell me a joke')
      chat.handle_slash_command('/retry')
    end

    it 'adds an empty assistant message before sending' do
      allow(chat).to receive(:send_to_llm)
      chat.handle_slash_command('/retry')
      assistant_msgs = chat.message_stream.messages.select { |m| m[:role] == :assistant }
      expect(assistant_msgs).not_to be_empty
    end

    it 'notifies "Retrying..."' do
      expect(chat.status_bar).to receive(:notify).with(hash_including(message: 'Retrying...'))
      chat.handle_slash_command('/retry')
    end

    it 'removes the last assistant message before resending' do
      chat.message_stream.add_message(role: :user, content: 'tell me a joke')
      chat.message_stream.add_message(role: :assistant, content: 'old response')
      initial_count = chat.message_stream.messages.size
      allow(chat).to receive(:send_to_llm)
      chat.handle_slash_command('/retry')
      # old assistant removed, new empty one added — net count stays same
      expect(chat.message_stream.messages.size).to eq(initial_count)
    end

    it 'does not remove last assistant if none present' do
      chat.message_stream.add_message(role: :user, content: 'tell me a joke')
      count_before = chat.message_stream.messages.size
      allow(chat).to receive(:send_to_llm)
      chat.handle_slash_command('/retry')
      # no assistant to remove, one new empty assistant added
      expect(chat.message_stream.messages.size).to eq(count_before + 1)
    end
  end

  describe '@last_user_input tracking' do
    it 'starts as nil' do
      expect(chat.instance_variable_get(:@last_user_input)).to be_nil
    end

    it 'is set after handle_user_message' do
      allow(chat).to receive(:send_to_llm)
      allow(chat).to receive(:check_autosave)
      chat.handle_user_message('hello world')
      expect(chat.instance_variable_get(:@last_user_input)).to eq('hello world')
    end
  end
end
