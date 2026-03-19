# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/split and /swap commands' do
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

  describe 'SLASH_COMMANDS registration' do
    it 'includes /split' do
      expect(described_class::SLASH_COMMANDS).to include('/split')
    end

    it 'includes /swap' do
      expect(described_class::SLASH_COMMANDS).to include('/swap')
    end
  end

  # ---------------------------------------------------------------------------
  # /split
  # ---------------------------------------------------------------------------

  describe '/split — argument validation' do
    it 'returns :handled with no arguments' do
      expect(chat.handle_slash_command('/split')).to eq(:handled)
    end

    it 'shows usage when no index given' do
      chat.handle_slash_command('/split')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Usage:')
      expect(msgs.last[:content]).to include('/split')
    end

    it 'shows usage when index is non-numeric' do
      chat.handle_slash_command('/split abc')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Usage:')
    end

    it 'shows out-of-range error when index exceeds message count' do
      chat.handle_slash_command('/split 99')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('No message at index 99')
    end
  end

  describe '/split — default paragraph break pattern' do
    before do
      chat.message_stream.add_message(role: :user, content: "para one\n\npara two\n\npara three")
    end

    it 'returns :handled' do
      expect(chat.handle_slash_command('/split 0')).to eq(:handled)
    end

    it 'shows "Split into X messages" confirmation' do
      chat.handle_slash_command('/split 0')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to eq('Split into 3 messages.')
    end

    it 'replaces the original message with the split segments' do
      chat.handle_slash_command('/split 0')
      non_system = chat.message_stream.messages.reject { |m| m[:role] == :system }
      contents = non_system.map { |m| m[:content] }
      expect(contents).to include('para one')
      expect(contents).to include('para two')
      expect(contents).to include('para three')
    end

    it 'preserves the original role on each segment' do
      chat.handle_slash_command('/split 0')
      non_system = chat.message_stream.messages.reject { |m| m[:role] == :system }
      expect(non_system.map { |m| m[:role] }.uniq).to eq([:user])
    end

    it 'inserts segments at the original position' do
      chat.message_stream.add_message(role: :assistant, content: 'after')
      chat.handle_slash_command('/split 0')
      non_system = chat.message_stream.messages.reject { |m| m[:role] == :system }
      expect(non_system.last[:content]).to eq('after')
    end
  end

  describe '/split — custom pattern' do
    before do
      chat.message_stream.add_message(role: :assistant, content: 'alpha---beta---gamma')
    end

    it 'splits on the given pattern' do
      chat.handle_slash_command('/split 0 ---')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to eq('Split into 3 messages.')
    end

    it 'produces segments matching the custom delimiter' do
      chat.handle_slash_command('/split 0 ---')
      non_system = chat.message_stream.messages.reject { |m| m[:role] == :system }
      contents = non_system.map { |m| m[:content] }
      expect(contents).to include('alpha')
      expect(contents).to include('beta')
      expect(contents).to include('gamma')
    end
  end

  describe '/split — no pattern found in message' do
    before do
      chat.message_stream.add_message(role: :user, content: 'no double newline here')
    end

    it 'returns :handled' do
      expect(chat.handle_slash_command('/split 0')).to eq(:handled)
    end

    it 'reports that the message could not be split' do
      chat.handle_slash_command('/split 0')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('could not be split')
    end

    it 'leaves the original message intact' do
      original_count = chat.message_stream.messages.size
      chat.handle_slash_command('/split 0')
      non_system = chat.message_stream.messages.reject { |m| m[:role] == :system }
      expect(non_system.size).to eq(original_count)
    end
  end

  # ---------------------------------------------------------------------------
  # /swap
  # ---------------------------------------------------------------------------

  describe '/swap — argument validation' do
    it 'returns :handled with no arguments' do
      expect(chat.handle_slash_command('/swap')).to eq(:handled)
    end

    it 'shows usage when no arguments given' do
      chat.handle_slash_command('/swap')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Usage:')
      expect(msgs.last[:content]).to include('/swap')
    end

    it 'shows usage when only one index given' do
      chat.handle_slash_command('/swap 0')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Usage:')
    end

    it 'shows usage when indices are non-numeric' do
      chat.handle_slash_command('/swap a b')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Usage:')
    end

    it 'shows out-of-range error when index A is too large' do
      chat.message_stream.add_message(role: :user, content: 'only one')
      chat.handle_slash_command('/swap 0 99')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('out of range')
    end

    it 'shows out-of-range error when index B is too large' do
      chat.message_stream.add_message(role: :user, content: 'only one')
      chat.handle_slash_command('/swap 99 0')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('out of range')
    end
  end

  describe '/swap — successful swap' do
    before do
      chat.message_stream.add_message(role: :user, content: 'first')
      chat.message_stream.add_message(role: :assistant, content: 'second')
    end

    it 'returns :handled' do
      expect(chat.handle_slash_command('/swap 0 1')).to eq(:handled)
    end

    it 'swaps the two messages by index' do
      chat.handle_slash_command('/swap 0 1')
      msgs = chat.message_stream.messages.reject { |m| m[:role] == :system }
      expect(msgs[0][:content]).to eq('second')
      expect(msgs[1][:content]).to eq('first')
    end

    it 'shows confirmation with both indices' do
      chat.handle_slash_command('/swap 0 1')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('0')
      expect(msgs.last[:content]).to include('1')
      expect(msgs.last[:content]).to include('Swapped')
    end

    it 'preserves the roles after the swap (roles travel with messages)' do
      chat.handle_slash_command('/swap 0 1')
      msgs = chat.message_stream.messages.reject { |m| m[:role] == :system }
      expect(msgs[0][:role]).to eq(:assistant)
      expect(msgs[1][:role]).to eq(:user)
    end

    it 'does not change the total message count' do
      original_count = chat.message_stream.messages.size
      chat.handle_slash_command('/swap 0 1')
      non_sys_count = chat.message_stream.messages.reject { |m| m[:role] == :system }.size
      expect(non_sys_count).to eq(original_count)
    end
  end

  describe '/swap — swapping a message with itself' do
    before do
      chat.message_stream.add_message(role: :user, content: 'solo')
    end

    it 'returns :handled' do
      expect(chat.handle_slash_command('/swap 0 0')).to eq(:handled)
    end

    it 'leaves the message unchanged' do
      chat.handle_slash_command('/swap 0 0')
      msgs = chat.message_stream.messages.reject { |m| m[:role] == :system }
      expect(msgs[0][:content]).to eq('solo')
    end
  end
end
