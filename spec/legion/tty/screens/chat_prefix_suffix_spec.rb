# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/prefix and /suffix commands' do
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

  describe 'SLASH_COMMANDS registration' do
    it 'includes /prefix' do
      expect(described_class::SLASH_COMMANDS).to include('/prefix')
    end

    it 'includes /suffix' do
      expect(described_class::SLASH_COMMANDS).to include('/suffix')
    end
  end

  describe '/prefix' do
    it 'returns :handled' do
      expect(chat.handle_slash_command('/prefix Hello')).to eq(:handled)
    end

    it 'sets the prefix and confirms' do
      chat.handle_slash_command('/prefix [URGENT] ')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Prefix set')
      expect(content).to include('[URGENT]')
    end

    it 'shows current prefix when called with no args' do
      chat.handle_slash_command('/prefix Context: ')
      chat.handle_slash_command('/prefix')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Current prefix')
      expect(content).to include('Context:')
    end

    it 'shows usage when no prefix is set and called with no args' do
      chat.handle_slash_command('/prefix')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('No prefix set')
      expect(content).to include('Usage:')
    end

    it 'clears the prefix with "clear"' do
      chat.handle_slash_command('/prefix Something')
      chat.handle_slash_command('/prefix clear')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Prefix cleared')
    end

    it 'shows no prefix after clearing' do
      chat.handle_slash_command('/prefix Something')
      chat.handle_slash_command('/prefix clear')
      chat.handle_slash_command('/prefix')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('No prefix set')
    end
  end

  describe '/suffix' do
    it 'returns :handled' do
      expect(chat.handle_slash_command('/suffix -- end')).to eq(:handled)
    end

    it 'sets the suffix and confirms' do
      chat.handle_slash_command('/suffix [END]')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Suffix set')
      expect(content).to include('[END]')
    end

    it 'shows current suffix when called with no args' do
      chat.handle_slash_command('/suffix -- signed')
      chat.handle_slash_command('/suffix')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Current suffix')
      expect(content).to include('-- signed')
    end

    it 'shows usage when no suffix is set and called with no args' do
      chat.handle_slash_command('/suffix')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('No suffix set')
      expect(content).to include('Usage:')
    end

    it 'clears the suffix with "clear"' do
      chat.handle_slash_command('/suffix text')
      chat.handle_slash_command('/suffix clear')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Suffix cleared')
    end

    it 'shows no suffix after clearing' do
      chat.handle_slash_command('/suffix text')
      chat.handle_slash_command('/suffix clear')
      chat.handle_slash_command('/suffix')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('No suffix set')
    end
  end

  describe 'apply_message_decorators' do
    it 'prepends prefix to messages' do
      chat.handle_slash_command('/prefix [Q] ')
      result = chat.send(:apply_message_decorators, 'hello')
      expect(result).to eq('[Q] hello')
    end

    it 'appends suffix to messages' do
      chat.handle_slash_command('/suffix --end')
      result = chat.send(:apply_message_decorators, 'hello')
      expect(result).to eq('hello--end')
    end

    it 'applies both prefix and suffix' do
      chat.handle_slash_command('/prefix [Q] ')
      chat.handle_slash_command('/suffix [/Q]')
      result = chat.send(:apply_message_decorators, 'hello')
      expect(result).to eq('[Q] hello[/Q]')
    end

    it 'returns original message when no prefix or suffix is set' do
      result = chat.send(:apply_message_decorators, 'hello')
      expect(result).to eq('hello')
    end
  end
end
